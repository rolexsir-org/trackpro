'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createBillingServer } = require('../src/server');
const { BillingStore } = require('../src/store');
const { PlayPurchaseVerifier } = require('../src/verifier');
const { RateLimiter, createLogger } = require('../src/security');

const FIXED_NOW = new Date('2026-10-18T12:00:00.000Z');

async function withServer(options, fn) {
  const logs = [];
  const store = options.store || new BillingStore(null);
  const verifier =
    options.verifier ||
    new PlayPurchaseVerifier({
      playClient: options.playClient || {
        async getSubscriptionV2() {
          return {
            subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
            lineItems: [
              {
                productId: 'track_pro_annual',
                expiryTime: '2027-10-18T12:00:00.000Z',
                autoRenewingPlan: { autoRenewEnabled: true },
              },
            ],
          };
        },
        async getProduct() {
          return { purchaseState: 0 };
        },
      },
      now: () => FIXED_NOW,
    });

  const srv = createBillingServer({
    verifier,
    store,
    apiKeys: options.apiKeys ?? ['test_api_key_secret'],
    rtdnSecret: options.rtdnSecret ?? null,
    integrityVerifier: options.integrityVerifier ?? null,
    rateLimiter: options.rateLimiter ?? new RateLimiter({ capacity: 50, refillPerSec: 10 }),
    logger: createLogger((line) => logs.push(line)),
    maxBodyBytes: options.maxBodyBytes ?? 4096,
  });

  await new Promise((resolve) => srv.listen(0, '127.0.0.1', resolve));
  const { port } = srv.address();
  const baseUrl = `http://127.0.0.1:${port}`;
  try {
    await fn({ baseUrl, store, logs });
  } finally {
    await new Promise((resolve) => srv.close(resolve));
  }
}

test('server.1: POST /billing/verify returns 200 valid verdict shape matching HttpPurchaseVerifier', async () => {
  await withServer({}, async ({ baseUrl }) => {
    const res = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer test_api_key_secret',
      },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: 'tok_live_annual_12345678',
        packageName: 'com.track.app',
      }),
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.valid, true);
    assert.equal(body.expiresAt, '2027-10-18T12:00:00.000Z');
    assert.equal(body.autoRenew, true);
    assert.equal(body.inGracePeriod, false);
  });
});

test('server.2: POST /billing/verify returns 401 without or with wrong Bearer token', async () => {
  await withServer({}, async ({ baseUrl }) => {
    const r1 = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: 'tok_12345678',
        packageName: 'com.track.app',
      }),
    });
    assert.equal(r1.status, 401);

    const r2 = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer wrong_token',
      },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: 'tok_12345678',
        packageName: 'com.track.app',
      }),
    });
    assert.equal(r2.status, 401);
  });
});

test('server.3: forged token returns 200 {valid:false, reason:token_not_found}, not 503', async () => {
  await withServer(
    {
      playClient: {
        async getSubscriptionV2() {
          const err = new Error('Not found');
          err.statusCode = 404;
          throw err;
        },
      },
    },
    async ({ baseUrl }) => {
      const res = await fetch(`${baseUrl}/billing/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_api_key_secret',
        },
        body: JSON.stringify({
          productId: 'track_pro_annual',
          purchaseToken: 'forged_token_abcdef12345',
          packageName: 'com.track.app',
        }),
      });
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.valid, false);
      assert.equal(body.reason, 'token_not_found');
    }
  );
});

test('server.4: Play API outage returns 503 retryable so client does not revoke Pro', async () => {
  await withServer(
    {
      playClient: {
        async getSubscriptionV2() {
          const err = new Error('Upstream timeout');
          err.statusCode = 503;
          throw err;
        },
      },
    },
    async ({ baseUrl }) => {
      const res = await fetch(`${baseUrl}/billing/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_api_key_secret',
        },
        body: JSON.stringify({
          productId: 'track_pro_annual',
          purchaseToken: 'valid_token_during_outage',
          packageName: 'com.track.app',
        }),
      });
      assert.equal(res.status, 503);
      const body = await res.json();
      assert.equal(body.valid, false);
      assert.equal(body.retryable, true);
    }
  );
});

test('server.5: pending purchase returns 200 {valid:false, pending:true}', async () => {
  await withServer(
    {
      playClient: {
        async getSubscriptionV2() {
          return {
            subscriptionState: 'SUBSCRIPTION_STATE_PENDING',
            lineItems: [{ productId: 'track_pro_monthly' }],
          };
        },
      },
    },
    async ({ baseUrl }) => {
      const res = await fetch(`${baseUrl}/billing/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_api_key_secret',
        },
        body: JSON.stringify({
          productId: 'track_pro_monthly',
          purchaseToken: 'pending_upi_token_12345',
          packageName: 'com.track.app',
        }),
      });
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.valid, false);
      assert.equal(body.pending, true);
    }
  );
});

test('server.6: repeated verification of the same token is idempotent in the store', async () => {
  await withServer({}, async ({ baseUrl, store }) => {
    for (let i = 0; i < 3; i++) {
      const res = await fetch(`${baseUrl}/billing/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_api_key_secret',
        },
        body: JSON.stringify({
          productId: 'track_pro_annual',
          purchaseToken: 'tok_idempotent_12345678',
          packageName: 'com.track.app',
          installId: 'install_abc',
        }),
      });
      assert.equal(res.status, 200);
    }
    assert.equal(store.purchaseCount(), 1);
    assert.equal(store.installCount(), 1);
  });
});

test('server.7: raw purchaseToken never appears in any emitted log line', async () => {
  const rawToken = 'super_secret_raw_purchase_token_999888777';
  await withServer({}, async ({ baseUrl, logs }) => {
    await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer test_api_key_secret',
      },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: rawToken,
        packageName: 'com.track.app',
      }),
    });
    assert.ok(logs.length > 0);
    for (const line of logs) {
      assert.equal(line.includes(rawToken), false);
    }
  });
});

test('server.8: malformed JSON and missing fields return 400', async () => {
  await withServer({}, async ({ baseUrl }) => {
    const r1 = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer test_api_key_secret',
      },
      body: '{bad-json',
    });
    assert.equal(r1.status, 400);

    const r2 = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer test_api_key_secret',
      },
      body: JSON.stringify({ productId: 'track_pro_annual' }),
    });
    assert.equal(r2.status, 400);
  });
});

test('server.9: oversized request body returns 413 cleanly', async () => {
  await withServer({ maxBodyBytes: 128 }, async ({ baseUrl }) => {
    const res = await fetch(`${baseUrl}/billing/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer test_api_key_secret',
      },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: 'x'.repeat(512),
        packageName: 'com.track.app',
      }),
    });
    assert.equal(res.status, 413);
  });
});

test('server.10: burst traffic exceeding rate limit receives 429', async () => {
  const rateLimiter = new RateLimiter({ capacity: 1, refillPerSec: 0 });
  await withServer({ rateLimiter }, async ({ baseUrl }) => {
    const r1 = await fetch(`${baseUrl}/healthz`);
    assert.equal(r1.status, 200);

    const reqInit = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer test_api_key_secret',
      },
      body: JSON.stringify({
        productId: 'track_pro_annual',
        purchaseToken: 'tok_burst_12345678',
        packageName: 'com.track.app',
      }),
    };
    const r2 = await fetch(`${baseUrl}/billing/verify`, reqInit);
    assert.equal(r2.status, 200);
    const r3 = await fetch(`${baseUrl}/billing/verify`, reqInit);
    assert.equal(r3.status, 429);
  });
});

test('server.11: GET /healthz returns 200 {ok:true} and leaks no internal state', async () => {
  await withServer({}, async ({ baseUrl }) => {
    const res = await fetch(`${baseUrl}/healthz`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body, { ok: true });
  });
});

test('server.12: POST /rtdn processes revocation push and drops stored purchase', async () => {
  await withServer({ rtdnSecret: 'rtdn_push_secret' }, async ({ baseUrl, store }) => {
    store.upsertPurchase({
      purchaseToken: 'tok_rtdn_live_123456',
      productId: 'track_pro_annual',
      packageName: 'com.track.app',
    });
    const envelope = {
      message: {
        data: Buffer.from(
          JSON.stringify({
            packageName: 'com.track.app',
            subscriptionNotification: {
              notificationType: 12,
              purchaseToken: 'tok_rtdn_live_123456',
              subscriptionId: 'track_pro_annual',
            },
          }),
          'utf8'
        ).toString('base64'),
      },
    };
    const res = await fetch(`${baseUrl}/rtdn`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer rtdn_push_secret',
      },
      body: JSON.stringify(envelope),
    });
    assert.equal(res.status, 200);
    assert.equal(store.getPurchase('tok_rtdn_live_123456'), null);
  });
});
