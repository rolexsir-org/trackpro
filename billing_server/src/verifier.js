'use strict';

const { sanitizePlayError } = require('./security');

const EXPECTED_PACKAGE = 'com.track.app';

const PRODUCTS = Object.freeze({
  track_pro_monthly: { kind: 'subscription' },
  track_pro_annual: { kind: 'subscription' },
  track_pro_lifetime: { kind: 'product' },
});

/**
 * Verifies a purchase token against the Google Play Developer API (`playClient`)
 * and enforces Track Pro's fail-closed entitlement rules:
 *
 *  * packageName must match `com.track.app`;
 *  * productId must be in the catalogue allowlist;
 *  * purchaseToken must be a plausible non-empty string before touching Google;
 *  * subscriptions use `purchases.subscriptionsv2.get`:
 *      - `SUBSCRIPTION_STATE_PENDING` -> `{ valid: false, pending: true }`
 *      - `SUBSCRIPTION_STATE_ACTIVE` / `IN_GRACE_PERIOD` / `CANCELED` require a
 *        future `expiryTime` (even if Google's state string still says ACTIVE!);
 *      - `REVOKED` / `EXPIRED` / `ON_HOLD` / `PAUSED` -> `{ valid: false, reason }`
 *  * one-time products (`track_pro_lifetime`) use `purchases.products.get`:
 *      - `purchaseState === 0` -> `{ valid: true, expiresAt: null, autoRenew: false }`
 *      - `purchaseState === 2` -> `{ valid: false, pending: true }`
 *      - `purchaseState === 1` -> `{ valid: false, reason: 'canceled' }`
 *  * Play API 404 / 410 -> `{ valid: false, reason: 'token_not_found' }` (definitive verdict)
 *  * Play API 5xx / timeout / network failure -> `{ valid: false, retryable: true, reason: 'play_unreachable' }`
 */
class PlayPurchaseVerifier {
  constructor({
    playClient,
    expectedPackage = EXPECTED_PACKAGE,
    now = () => new Date(),
  }) {
    if (!playClient) throw new Error('playClient is required');
    this.playClient = playClient;
    this.expectedPackage = expectedPackage;
    this.now = now;
  }

  async verify({ productId, purchaseToken, packageName }) {
    if (packageName !== this.expectedPackage) {
      return { valid: false, reason: 'package_mismatch' };
    }
    const spec = PRODUCTS[productId];
    if (!spec) {
      return { valid: false, reason: 'unknown_product' };
    }
    if (typeof purchaseToken !== 'string' || purchaseToken.trim().length < 8) {
      return { valid: false, reason: 'invalid_token_format' };
    }
    const token = purchaseToken.trim();

    try {
      if (spec.kind === 'subscription') {
        return await this._verifySubscription(productId, token);
      }
      return await this._verifyOneTimeProduct(productId, token);
    } catch (rawErr) {
      const err = sanitizePlayError(rawErr);
      if (err.statusCode === 404 || err.statusCode === 410 || err.code === 'token_not_found') {
        return { valid: false, reason: 'token_not_found' };
      }
      if (err.statusCode === 400 || err.code === 'invalid_token') {
        return { valid: false, reason: 'invalid_token' };
      }
      return {
        valid: false,
        retryable: true,
        reason: 'play_unreachable',
      };
    }
  }

  async _verifySubscription(productId, purchaseToken) {
    const res = await this.playClient.getSubscriptionV2({
      packageName: this.expectedPackage,
      purchaseToken,
    });
    if (!res || typeof res !== 'object') {
      return { valid: false, retryable: true, reason: 'play_unreachable' };
    }

    const state = res.subscriptionState || '';
    const lineItem = Array.isArray(res.lineItems) && res.lineItems.length > 0 ? res.lineItems[0] : {};
    if (lineItem.productId && lineItem.productId !== productId) {
      return { valid: false, reason: 'product_mismatch' };
    }

    const expiryIso = lineItem.expiryTime || res.expiryTime || null;
    const expiryDate = expiryIso ? new Date(expiryIso) : null;
    const hasValidExpiry = expiryDate instanceof Date && !Number.isNaN(expiryDate.getTime());

    if (state === 'SUBSCRIPTION_STATE_PENDING') {
      return {
        valid: false,
        pending: true,
        expiresAt: hasValidExpiry ? expiryDate.toISOString() : null,
        reason: 'pending',
      };
    }

    if (
      state === 'SUBSCRIPTION_STATE_REVOKED' ||
      state === 'SUBSCRIPTION_STATE_EXPIRED' ||
      state === 'SUBSCRIPTION_STATE_ON_HOLD' ||
      state === 'SUBSCRIPTION_STATE_PAUSED'
    ) {
      return {
        valid: false,
        reason: state.replace('SUBSCRIPTION_STATE_', '').toLowerCase(),
      };
    }

    if (
      state === 'SUBSCRIPTION_STATE_ACTIVE' ||
      state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
      state === 'SUBSCRIPTION_STATE_CANCELED'
    ) {
      // A subscription with no expiry timestamp cannot be trusted, and an expired
      // timestamp is rejected even if Google's state string has not flipped yet.
      if (!hasValidExpiry) {
        return { valid: false, reason: 'missing_expiry' };
      }
      if (expiryDate.getTime() <= this.now().getTime()) {
        return { valid: false, reason: 'expired' };
      }
      const autoRenew =
        lineItem.autoRenewingPlan && typeof lineItem.autoRenewingPlan.autoRenewEnabled === 'boolean'
          ? lineItem.autoRenewingPlan.autoRenewEnabled
          : state !== 'SUBSCRIPTION_STATE_CANCELED';

      return {
        valid: true,
        expiresAt: expiryDate.toISOString(),
        trialEndsAt: res.trialEndsAt || lineItem.trialEndsAt || null,
        autoRenew,
        inGracePeriod: state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        reason: 'server',
      };
    }

    return { valid: false, reason: 'unrecognized_state' };
  }

  async _verifyOneTimeProduct(productId, purchaseToken) {
    const res = await this.playClient.getProduct({
      packageName: this.expectedPackage,
      productId,
      purchaseToken,
    });
    if (!res || typeof res !== 'object') {
      return { valid: false, retryable: true, reason: 'play_unreachable' };
    }

    // Play products.get purchaseState: 0 = Purchased, 1 = Canceled, 2 = Pending
    if (res.purchaseState === 2) {
      return { valid: false, pending: true, reason: 'pending' };
    }
    if (res.purchaseState === 1) {
      return { valid: false, reason: 'canceled' };
    }
    if (res.purchaseState === 0) {
      return {
        valid: true,
        expiresAt: null,
        trialEndsAt: null,
        autoRenew: false,
        inGracePeriod: false,
        reason: 'server',
      };
    }
    return { valid: false, reason: 'unrecognized_product_state' };
  }
}

module.exports = { PlayPurchaseVerifier, PRODUCTS, EXPECTED_PACKAGE };
