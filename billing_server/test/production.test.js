'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');

const { createBillingServer } = require('../src/server');
const { BillingStore } = require('../src/store');
const { RateLimiter, createLogger } = require('../src/security');

const ROOT = path.join(__dirname, '..');

function getFreePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

function waitForHealth(baseUrl, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve, reject) => {
    const attempt = async () => {
      try {
        const res = await fetch(`${baseUrl}/healthz`);
        if (res.status === 200) return resolve();
      } catch (_) {
        /* retry */
      }
      if (Date.now() > deadline) return reject(new Error('health check timeout'));
      setTimeout(attempt, 150);
    };
    attempt();
  });
}

// A store whose writes throw a filesystem-style error, used to exercise the
// fail-safe storage-failure paths added to the HTTP layer.
function throwingStore(code = 'ENOSPC') {
  const err = new Error(`storage failure (${code})`);
  err.code = code;
  return {
    upsertPurchase() {
      throw err;
    },
    revokeByToken() {
      throw err;
    },
  };
}

async function withServer(options, fn) {
  const logs = [];
  const store = options.store || new BillingStore(null);
  const verifier =
    options.verifier ||
    {
      async verify() {
        return {
          valid: true,
          expiresAt: '2030-01-01T00:00:00.000Z',
          trialEndsAt: null,
          autoRenew: true,
          inGracePeriod: false,
          reason: 'server',
        };
      },
    };
  const srv = createBillingServer({
    verifier,
    store,
    apiKeys: ['test_api_key_secret'],
    rtdnSecret: 'rtdn_secret',
    rateLimiter: new RateLimiter({ capacity: 50, refillPerSec: 10 }),
    logger: createLogger((line) => logs.push(line)),
    maxBodyBytes: 4096,
  });
  await new Promise((resolve) => srv.listen(0, '127.0.0.1', resolve));
  const { port } = srv.address();
  const baseUrl = `http://127.0.0.1:${port}`;
  try {
    await fn({ baseUrl, store, logs });
  } finally {
    await new Promise((r) => srv.close(r));
  }
}

test('prod.1: storage write failure during verify returns 503 retryable (never 200)', async () => {
  await withServer({ store: throwingStore('ENOSPC') }, async ({ baseUrl, logs }) => {
    const res = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer test_api_key_secret' },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: 'tok_storage_12345678',
        packageName: 'com.track.app',
      }),
    });
    assert.equal(res.status, 503);
    const body = await res.json();
    assert.equal(body.valid, false);
    assert.equal(body.retryable, true);
    assert.equal(body.reason, 'store_unavailable');
    assert.ok(logs.some((l) => JSON.parse(l).event === 'store_error'));
  });
});

test('prod.2: storage failure during RTDN returns 503 so Pub/Sub redelivers (not dropped)', async () => {
  await withServer({ store: throwingStore('EACCES') }, async ({ baseUrl, logs }) => {
    const envelope = {
      message: {
        data: Buffer.from(
          JSON.stringify({
            packageName: 'com.track.app',
            subscriptionNotification: {
              notificationType: 12,
              purchaseToken: 'tok_rtdn_12345678',
              subscriptionId: 'track_pro_annual',
            },
          }),
          'utf8',
        ).toString('base64'),
      },
    };
    const res = await fetch(`${baseUrl}/rtdn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer rtdn_secret' },
      body: JSON.stringify(envelope),
    });
    assert.equal(res.status, 503);
    const body = await res.json();
    assert.equal(body.ok, false);
    assert.equal(body.reason, 'store_unavailable');
    assert.ok(
      logs.some((l) => {
        const p = JSON.parse(l);
        return p.event === 'rtdn_error' && p.storage === true;
      }),
    );
  });
});

test('prod.3: HTTP server binds to 0.0.0.0 (Railway requires a non-loopback bind)', () => {
  return new Promise((resolve, reject) => {
    const srv = createBillingServer({
      verifier: { async verify() { return { valid: false, reason: 'unknown_product' }; } },
      store: new BillingStore(null),
      apiKeys: ['k'],
      rateLimiter: new RateLimiter(),
      logger: createLogger(() => {}),
    });
    srv.listen(0, '0.0.0.0', () => {
      try {
        assert.equal(srv.address().address, '0.0.0.0');
        srv.close(resolve);
      } catch (err) {
        srv.close(() => reject(err));
      }
    });
  });
});

test('prod.4: production entry point starts, serves /healthz, and shuts down cleanly on SIGTERM', { timeout: 30000 }, async () => {
  const port = await getFreePort();
  const storeDir = fs.mkdtempSync(path.join(os.tmpdir(), 'trackprod-'));
  const storePath = path.join(storeDir, 'purchases.json');
  const fakeCreds = JSON.stringify({
    client_email: 'billing-fake@fake.iam.gserviceaccount.com',
    private_key: 'FAKE_KEY_NOT_USED_AT_STARTUP',
  });

  const child = spawn(process.execPath, ['src/index.js'], {
    cwd: ROOT,
    env: {
      ...process.env,
      PORT: String(port),
      TRACK_BILLING_API_KEYS: 'key_a,key_b',
      TRACK_RTDN_SECRET: 'rtdn_secret',
      TRACK_STORE_PATH: storePath,
      GOOGLE_APPLICATION_CREDENTIALS_JSON: fakeCreds,
      NODE_ENV: 'production',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const out = [];
  child.stdout.on('data', (d) => out.push(d.toString()));
  child.stderr.on('data', (d) => out.push(d.toString()));

  try {
    await waitForHealth(`http://127.0.0.1:${port}`, 15000);
    assert.ok(out.join('').includes('service_started'), 'expected service_started log');

    // Health endpoint is liveness-only and does not require Google Play creds.
    const health = await fetch(`http://127.0.0.1:${port}/healthz`);
    assert.equal(health.status, 200);
    assert.deepEqual(await health.json(), { ok: true });

    child.kill('SIGTERM');
    const code = await new Promise((res, rej) => {
      const t = setTimeout(() => rej(new Error('did not exit after SIGTERM')), 9000);
      child.on('exit', (c) => {
        clearTimeout(t);
        res(c);
      });
    });
    assert.equal(code, 0);
    assert.ok(out.join('').includes('service_stopping'), 'expected service_stopping log');
  } finally {
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    fs.rmSync(storeDir, { recursive: true, force: true });
  }
});

test('prod.5: invalid Google credentials cause a clean startup failure (exit 1, service_failed)', { timeout: 20000 }, async () => {
  const port = await getFreePort();
  const child = spawn(process.execPath, ['src/index.js'], {
    cwd: ROOT,
    env: {
      ...process.env,
      PORT: String(port),
      TRACK_BILLING_API_KEYS: 'key_a',
      TRACK_RTDN_SECRET: 'rtdn_secret',
      TRACK_STORE_PATH: path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'trackbad-')), 'p.json'),
      GOOGLE_APPLICATION_CREDENTIALS_JSON: 'this-is-not-json',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const out = [];
  child.stdout.on('data', (d) => out.push(d.toString()));
  child.stderr.on('data', (d) => out.push(d.toString()));

  const code = await new Promise((res) => {
    const t = setTimeout(() => {
      child.kill('SIGKILL');
      res('timeout');
    }, 12000);
    child.on('exit', (c) => {
      clearTimeout(t);
      res(c);
    });
  });

  assert.equal(code, 1, 'service must refuse to start with invalid credentials');
  assert.ok(out.join('').includes('service_failed'), 'expected service_failed log');
});
