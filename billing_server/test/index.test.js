'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { createService } = require('../src/index');
const { createLogger } = require('../src/security');

const FIXED_NOW = new Date('2026-11-01T12:00:00.000Z');

function fakePlayClient() {
  return {
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [
          {
            productId: 'track_pro_annual',
            expiryTime: '2030-11-01T12:00:00.000Z',
            autoRenewingPlan: { autoRenewEnabled: true },
          },
        ],
      };
    },
    async getProduct() {
      return { purchaseState: 0 };
    },
  };
}

function tempStorePath() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'trackpro-billing-'));
  return path.join(dir, 'purchases.json');
}

function envWith(storePath, overrides = {}) {
  return {
    TRACK_BILLING_API_KEYS: 'key_one,key_two',
    TRACK_RTDN_SECRET: 'rtdn_secret',
    TRACK_STORE_PATH: storePath,
    ...overrides,
  };
}

async function withService(options, fn) {
  const storePath = options.storePath || tempStorePath();
  const service = createService({
    env: envWith(storePath, options.env),
    playClient: options.playClient || fakePlayClient(),
    logger: createLogger(() => {}),
    rateLimiter: options.rateLimiter,
  });
  await new Promise((resolve) => service.server.listen(0, '127.0.0.1', resolve));
  const { port } = service.server.address();
  const baseUrl = `http://127.0.0.1:${port}`;
  try {
    await fn({ baseUrl, service, storePath });
  } finally {
    await new Promise((resolve) => service.server.close(resolve));
    fs.rmSync(path.dirname(storePath), { recursive: true, force: true });
  }
}

test('service.1: refuses to start without API keys', () => {
  assert.throws(
    () => createService({ env: envWith(tempStorePath(), { TRACK_BILLING_API_KEYS: '' }), playClient: fakePlayClient() }),
    /TRACK_BILLING_API_KEYS/,
  );
});

test('service.2: refuses to start without an RTDN secret', () => {
  assert.throws(
    () => createService({ env: envWith(tempStorePath(), { TRACK_RTDN_SECRET: '' }), playClient: fakePlayClient() }),
    /TRACK_RTDN_SECRET/,
  );
});

test('service.3: refuses to start without a store path', () => {
  assert.throws(
    () => createService({ env: envWith('', { TRACK_STORE_PATH: '' }), playClient: fakePlayClient() }),
    /TRACK_STORE_PATH/,
  );
});

test('service.4: /healthz is public and leaks nothing', async () => {
  await withService({}, async ({ baseUrl }) => {
    const res = await fetch(`${baseUrl}/healthz`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { ok: true });
  });
});

test('service.5: /billing/verify requires the API key and verifies a purchase', async () => {
  await withService({}, async ({ baseUrl, service }) => {
    const noAuth = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ productId: 'track_pro_annual', purchaseToken: 'tok_123456', packageName: 'com.track.app' }),
    });
    assert.equal(noAuth.status, 401);

    const wrongKey = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer wrong_key' },
      body: JSON.stringify({ productId: 'track_pro_annual', purchaseToken: 'tok_123456', packageName: 'com.track.app' }),
    });
    assert.equal(wrongKey.status, 401);

    const ok = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer key_two' },
      body: JSON.stringify({ productId: 'track_pro_annual', purchaseToken: 'tok_123456', packageName: 'com.track.app' }),
    });
    assert.equal(ok.status, 200);
    const payload = await ok.json();
    assert.equal(payload.valid, true);
    assert.equal(payload.expiresAt, '2030-11-01T12:00:00.000Z');
    assert.equal(service.store.getPurchase('tok_123456').productId, 'track_pro_annual');
  });
});

test('service.6: /rtdn requires the RTDN secret and accepts a Pub/Sub test notification', async () => {
  await withService({}, async ({ baseUrl }) => {
    const noAuth = await fetch(`${baseUrl}/rtdn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: { data: Buffer.from(JSON.stringify({ testNotification: true })).toString('base64') } }),
    });
    assert.equal(noAuth.status, 401);

    const ok = await fetch(`${baseUrl}/rtdn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer rtdn_secret' },
      body: JSON.stringify({ message: { data: Buffer.from(JSON.stringify({ testNotification: true })).toString('base64') } }),
    });
    assert.equal(ok.status, 200);
    const payload = await ok.json();
    assert.equal(payload.ok, true);
    assert.equal(payload.action, 'test_notification');
  });
});

test('service.7: a revoked RTDN drops the stored entitlement', async () => {
  await withService({}, async ({ baseUrl, service }) => {
    const verify = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer key_one' },
      body: JSON.stringify({ productId: 'track_pro_annual', purchaseToken: 'tok_123456', packageName: 'com.track.app' }),
    });
    assert.equal(verify.status, 200);
    assert.ok(service.store.getPurchase('tok_123456'));

    const notification = {
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 12,
        purchaseToken: 'tok_123456',
        subscriptionId: 'track_pro_annual',
      },
    };
    const rtdn = await fetch(`${baseUrl}/rtdn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer rtdn_secret' },
      body: JSON.stringify({ message: { data: Buffer.from(JSON.stringify(notification)).toString('base64') } }),
    });
    assert.equal(rtdn.status, 200);
    const payload = await rtdn.json();
    assert.equal(payload.action, 'revoked');
    assert.equal(service.store.getPurchase('tok_123456'), null);
  });
});
