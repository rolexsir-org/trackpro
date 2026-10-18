'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { PlayPurchaseVerifier } = require('../src/verifier');

const FIXED_NOW = new Date('2026-10-18T12:00:00.000Z');

function makeVerifier(playOverrides = {}) {
  const playClient = {
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
    ...playOverrides,
  };
  return new PlayPurchaseVerifier({ playClient, now: () => FIXED_NOW });
}

test('verifier.1: rejects unknown productId outside the catalogue allowlist', async () => {
  const v = makeVerifier();
  const res = await v.verify({
    productId: 'track_pro_weekly_fake',
    purchaseToken: 'valid_looking_token_12345',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'unknown_product');
});

test('verifier.2: rejects packageName mismatch', async () => {
  const v = makeVerifier();
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'valid_looking_token_12345',
    packageName: 'com.spoofed.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'package_mismatch');
});

test('verifier.3: short or empty token is rejected without calling Google Play', async () => {
  let called = false;
  const v = makeVerifier({
    async getSubscriptionV2() {
      called = true;
      return {};
    },
  });
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'short',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'invalid_token_format');
  assert.equal(called, false);
});

test('verifier.4: Play 404 maps to definitive token_not_found verdict', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      const err = new Error('Not Found');
      err.statusCode = 404;
      throw err;
    },
  });
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'forged_token_12345678',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.retryable, undefined);
  assert.equal(res.reason, 'token_not_found');
});

test('verifier.5: active subscription with future expiry is valid', async () => {
  const v = makeVerifier();
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'real_token_12345678',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, true);
  assert.equal(res.expiresAt, '2027-10-18T12:00:00.000Z');
  assert.equal(res.autoRenew, true);
  assert.equal(res.inGracePeriod, false);
});

test('verifier.6: pending subscription returns valid:false, pending:true', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_PENDING',
        lineItems: [{ productId: 'track_pro_monthly' }],
      };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_monthly',
    purchaseToken: 'upi_pending_token_12345',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.pending, true);
});

test('verifier.7: expired timestamp is rejected even if Play state string still says ACTIVE', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [
          {
            productId: 'track_pro_monthly',
            expiryTime: '2026-10-01T00:00:00.000Z',
          },
        ],
      };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_monthly',
    purchaseToken: 'stale_active_token_12345',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'expired');
});

test('verifier.8: subscription in grace period with future expiry is valid and flags inGracePeriod', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        lineItems: [
          {
            productId: 'track_pro_monthly',
            expiryTime: '2026-10-22T00:00:00.000Z',
            autoRenewingPlan: { autoRenewEnabled: true },
          },
        ],
      };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_monthly',
    purchaseToken: 'grace_token_12345678',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, true);
  assert.equal(res.inGracePeriod, true);
});

test('verifier.9: canceled subscription remains valid until its future expiry with autoRenew:false', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
        lineItems: [
          {
            productId: 'track_pro_annual',
            expiryTime: '2027-03-01T00:00:00.000Z',
            autoRenewingPlan: { autoRenewEnabled: false },
          },
        ],
      };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'canceled_token_12345678',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, true);
  assert.equal(res.autoRenew, false);
});

test('verifier.10: revoked subscription is rejected', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_REVOKED',
        lineItems: [{ productId: 'track_pro_annual' }],
      };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'revoked_token_12345678',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'revoked');
});

test('verifier.11: lifetime product purchaseState 0 is valid with null expiry', async () => {
  const v = makeVerifier({
    async getProduct() {
      return { purchaseState: 0 };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_lifetime',
    purchaseToken: 'lifetime_token_12345678',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, true);
  assert.equal(res.expiresAt, null);
  assert.equal(res.autoRenew, false);
});

test('verifier.12: lifetime product purchaseState 1 (canceled) is rejected', async () => {
  const v = makeVerifier({
    async getProduct() {
      return { purchaseState: 1 };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_lifetime',
    purchaseToken: 'lifetime_canceled_12345',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'canceled');
});

test('verifier.13: lifetime product purchaseState 2 (pending) returns pending:true', async () => {
  const v = makeVerifier({
    async getProduct() {
      return { purchaseState: 2 };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_lifetime',
    purchaseToken: 'lifetime_pending_12345',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.pending, true);
});

test('verifier.14: Google Play 503 outage surfaces as retryable unavailability, never a rejection', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      const err = new Error('Play backend 503');
      err.statusCode = 503;
      throw err;
    },
  });
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'good_token_during_outage',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.retryable, true);
  assert.equal(res.reason, 'play_unreachable');
});

test('verifier.15: subscription response missing expiryTime is refused rather than assumed', async () => {
  const v = makeVerifier({
    async getSubscriptionV2() {
      return {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [{ productId: 'track_pro_annual' }],
      };
    },
  });
  const res = await v.verify({
    productId: 'track_pro_annual',
    purchaseToken: 'no_expiry_token_123456',
    packageName: 'com.track.app',
  });
  assert.equal(res.valid, false);
  assert.equal(res.reason, 'missing_expiry');
});
