'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { BillingStore } = require('../src/store');
const { handleRtdn, decodePubSubEnvelope } = require('../src/rtdn');

function pubsubWrap(payload) {
  return {
    message: {
      data: Buffer.from(JSON.stringify(payload), 'utf8').toString('base64'),
      messageId: 'msg_1',
    },
  };
}

test('rtdn.1: decodes base64 Pub/Sub push envelope cleanly', () => {
  const env = pubsubWrap({ packageName: 'com.track.app', testNotification: { version: '1.0' } });
  const decoded = decodePubSubEnvelope(env);
  assert.equal(decoded.packageName, 'com.track.app');
});

test('rtdn.2: SUBSCRIPTION_RENEWED (type 2) refreshes expiry via verifier', async () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_renew_12345678',
    productId: 'track_pro_monthly',
    packageName: 'com.track.app',
    expiresAt: '2026-11-01T00:00:00.000Z',
  });
  const verifier = {
    async verify() {
      return {
        valid: true,
        expiresAt: '2026-12-01T00:00:00.000Z',
        autoRenew: true,
        inGracePeriod: false,
      };
    },
  };
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 2,
        purchaseToken: 'tok_renew_12345678',
        subscriptionId: 'track_pro_monthly',
      },
    }),
    { store, verifier }
  );
  assert.equal(out.action, 'updated');
  assert.equal(store.getPurchase('tok_renew_12345678').expiresAt, '2026-12-01T00:00:00.000Z');
});

test('rtdn.3: SUBSCRIPTION_CANCELED (type 3) sets autoRenew:false without wiping stored expiry', async () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_cancel_12345678',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
    expiresAt: '2027-06-15T00:00:00.000Z',
    autoRenew: true,
  });
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 3,
        purchaseToken: 'tok_cancel_12345678',
        subscriptionId: 'track_pro_annual',
      },
    }),
    { store }
  );
  assert.equal(out.action, 'canceled_auto_renew');
  const rec = store.getPurchase('tok_cancel_12345678');
  assert.equal(rec.expiresAt, '2027-06-15T00:00:00.000Z');
  assert.equal(rec.autoRenew, false);
});

test('rtdn.4: SUBSCRIPTION_REVOKED (type 12) drops purchase and install entitlement immediately', async () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_revoke_12345678',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
    installId: 'inst_revoke_1',
  });
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 12,
        purchaseToken: 'tok_revoke_12345678',
        subscriptionId: 'track_pro_annual',
      },
    }),
    { store }
  );
  assert.equal(out.action, 'revoked');
  assert.equal(store.getPurchase('tok_revoke_12345678'), null);
  assert.equal(store.installCount(), 0);
});

test('rtdn.5: SUBSCRIPTION_EXPIRED (type 13) revokes stored purchase', async () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_exp_12345678',
    productId: 'track_pro_monthly',
    packageName: 'com.track.app',
  });
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 13,
        purchaseToken: 'tok_exp_12345678',
        subscriptionId: 'track_pro_monthly',
      },
    }),
    { store }
  );
  assert.equal(out.action, 'revoked');
  assert.equal(store.getPurchase('tok_exp_12345678'), null);
});

test('rtdn.6: SUBSCRIPTION_ON_HOLD (type 5) revokes active access', async () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_hold_12345678',
    productId: 'track_pro_monthly',
    packageName: 'com.track.app',
  });
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 5,
        purchaseToken: 'tok_hold_12345678',
        subscriptionId: 'track_pro_monthly',
      },
    }),
    { store }
  );
  assert.equal(out.action, 'revoked');
  assert.equal(store.getPurchase('tok_hold_12345678'), null);
});

test('rtdn.7: VOIDED_PURCHASE drops purchase and install entitlement', async () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_void_12345678',
    productId: 'track_pro_lifetime',
    packageName: 'com.track.app',
    installId: 'inst_void',
  });
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      voidedPurchaseNotification: {
        purchaseToken: 'tok_void_12345678',
        orderId: 'GPA.1234',
      },
    }),
    { store }
  );
  assert.equal(out.action, 'revoked');
  assert.equal(out.type, 'VOIDED_PURCHASE');
  assert.equal(store.getPurchase('tok_void_12345678'), null);
});

test('rtdn.8: unknown notificationType is acknowledged without mutating store', async () => {
  const store = new BillingStore(null);
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 999,
        purchaseToken: 'tok_unknown_type_123',
        subscriptionId: 'track_pro_monthly',
      },
    }),
    { store }
  );
  assert.equal(out.handled, true);
  assert.equal(out.action, 'ignored_unknown_type');
});

test('rtdn.9: unknown token on SUBSCRIPTION_CANCELED is safely ignored', async () => {
  const store = new BillingStore(null);
  const out = await handleRtdn(
    pubsubWrap({
      packageName: 'com.track.app',
      subscriptionNotification: {
        notificationType: 3,
        purchaseToken: 'tok_never_seen_12345',
        subscriptionId: 'track_pro_annual',
      },
    }),
    { store }
  );
  assert.equal(out.action, 'ignored_unknown_token');
});

test('rtdn.10: malformed Pub/Sub envelope is rejected', async () => {
  const store = new BillingStore(null);
  await assert.rejects(
    () => handleRtdn({ message: { data: '!!!not-json-base64!!!' } }, { store }),
    /Error|SyntaxError/
  );
});
