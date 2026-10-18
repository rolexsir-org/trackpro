'use strict';

const { EXPECTED_PACKAGE } = require('./verifier');

/**
 * Google Play Real-time Developer Notification (RTDN) codes for subscriptions:
 *   1  SUBSCRIPTION_RECOVERED
 *   2  SUBSCRIPTION_RENEWED
 *   3  SUBSCRIPTION_CANCELED
 *   4  SUBSCRIPTION_PURCHASED
 *   5  SUBSCRIPTION_ON_HOLD
 *   6  SUBSCRIPTION_IN_GRACE_PERIOD
 *   7  SUBSCRIPTION_RESTARTED
 *   10 SUBSCRIPTION_PAUSED
 *   12 SUBSCRIPTION_REVOKED
 *   13 SUBSCRIPTION_EXPIRED
 */
const SUB_TYPES = Object.freeze({
  1: 'SUBSCRIPTION_RECOVERED',
  2: 'SUBSCRIPTION_RENEWED',
  3: 'SUBSCRIPTION_CANCELED',
  4: 'SUBSCRIPTION_PURCHASED',
  5: 'SUBSCRIPTION_ON_HOLD',
  6: 'SUBSCRIPTION_IN_GRACE_PERIOD',
  7: 'SUBSCRIPTION_RESTARTED',
  10: 'SUBSCRIPTION_PAUSED',
  12: 'SUBSCRIPTION_REVOKED',
  13: 'SUBSCRIPTION_EXPIRED',
});

function decodePubSubEnvelope(body) {
  if (!body || typeof body !== 'object') {
    throw new Error('Malformed Pub/Sub envelope');
  }
  const msg = body.message;
  if (!msg || typeof msg.data !== 'string' || !msg.data.trim()) {
    throw new Error('Missing Pub/Sub message.data');
  }
  const json = Buffer.from(msg.data, 'base64').toString('utf8');
  const parsed = JSON.parse(json);
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('Decoded RTDN payload is not an object');
  }
  return parsed;
}

/**
 * Processes a decoded RTDN notification or raw Pub/Sub push envelope against
 * [store] (and optionally [verifier] when a renewal/recovery should pull fresh
 * expiry dates from Google Play).
 */
async function handleRtdn(envelopeOrNotification, { store, verifier, expectedPackage = EXPECTED_PACKAGE } = {}) {
  if (!store) throw new Error('store is required');
  const payload =
    envelopeOrNotification && envelopeOrNotification.message
      ? decodePubSubEnvelope(envelopeOrNotification)
      : envelopeOrNotification;

  if (!payload || typeof payload !== 'object') {
    throw new Error('Invalid RTDN payload');
  }

  if (payload.packageName && payload.packageName !== expectedPackage) {
    return { handled: false, reason: 'package_mismatch' };
  }

  if (payload.testNotification) {
    return { handled: true, action: 'test_notification' };
  }

  // Voided purchase notification (refund / chargeback on one-time or subscription)
  if (payload.voidedPurchaseNotification) {
    const { purchaseToken } = payload.voidedPurchaseNotification;
    if (!purchaseToken) throw new Error('Missing purchaseToken in voidedPurchaseNotification');
    const revoked = store.revokeByToken(purchaseToken, {
      packageName: payload.packageName || expectedPackage,
      reason: 'voided_purchase',
    });
    return { handled: true, action: 'revoked', revoked, type: 'VOIDED_PURCHASE' };
  }

  const sub = payload.subscriptionNotification;
  if (!sub) {
    return { handled: true, action: 'ignored_unrecognized_notification' };
  }

  const { notificationType, purchaseToken, subscriptionId } = sub;
  if (!purchaseToken) {
    throw new Error('Missing purchaseToken in subscriptionNotification');
  }
  const typeName = SUB_TYPES[notificationType] || `UNKNOWN_${notificationType}`;

  switch (typeName) {
    case 'SUBSCRIPTION_REVOKED':
    case 'SUBSCRIPTION_EXPIRED':
    case 'SUBSCRIPTION_ON_HOLD':
    case 'SUBSCRIPTION_PAUSED': {
      const revoked = store.revokeByToken(purchaseToken, {
        packageName: payload.packageName || expectedPackage,
        reason: typeName.toLowerCase(),
      });
      return { handled: true, action: 'revoked', revoked, type: typeName };
    }

    case 'SUBSCRIPTION_CANCELED': {
      // Cancellation turns off auto-renew; it MUST NOT wipe the stored expiry or
      // revoke access before the paid period ends.
      const existing = store.getPurchase(purchaseToken);
      if (!existing) {
        return { handled: true, action: 'ignored_unknown_token', type: typeName };
      }
      store.upsertPurchase({
        purchaseToken,
        productId: subscriptionId || existing.productId,
        packageName: payload.packageName || existing.packageName || expectedPackage,
        status: 'active',
        // Deliberately omit expiresAt so store.upsertPurchase preserves existing.expiresAt
        autoRenew: false,
      });
      return { handled: true, action: 'canceled_auto_renew', type: typeName };
    }

    case 'SUBSCRIPTION_RENEWED':
    case 'SUBSCRIPTION_RECOVERED':
    case 'SUBSCRIPTION_PURCHASED':
    case 'SUBSCRIPTION_RESTARTED':
    case 'SUBSCRIPTION_IN_GRACE_PERIOD': {
      let fresh = null;
      if (verifier && subscriptionId) {
        fresh = await verifier.verify({
          productId: subscriptionId,
          purchaseToken,
          packageName: payload.packageName || expectedPackage,
        });
      }
      const existing = store.getPurchase(purchaseToken);
      if (!fresh && !existing) {
        return { handled: true, action: 'ignored_unknown_token', type: typeName };
      }
      store.upsertPurchase({
        purchaseToken,
        productId: subscriptionId || (existing && existing.productId),
        packageName: payload.packageName || (existing && existing.packageName) || expectedPackage,
        status: 'active',
        expiresAt: fresh && fresh.expiresAt ? fresh.expiresAt : undefined,
        trialEndsAt: fresh && fresh.trialEndsAt !== undefined ? fresh.trialEndsAt : undefined,
        autoRenew: fresh && typeof fresh.autoRenew === 'boolean' ? fresh.autoRenew : true,
        inGracePeriod: typeName === 'SUBSCRIPTION_IN_GRACE_PERIOD' || Boolean(fresh && fresh.inGracePeriod),
      });
      return { handled: true, action: 'updated', type: typeName };
    }

    default:
      return { handled: true, action: 'ignored_unknown_type', type: typeName };
  }
}

module.exports = { handleRtdn, decodePubSubEnvelope, SUB_TYPES };
