'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { tokenRef } = require('./security');

const POSTGRES_DDL = `
CREATE TABLE IF NOT EXISTS billing_purchases (
  token_ref TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  status TEXT NOT NULL,
  expires_at TIMESTAMPTZ,
  trial_ends_at TIMESTAMPTZ,
  auto_renew BOOLEAN,
  in_grace_period BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS billing_install_entitlements (
  install_ref TEXT PRIMARY KEY,
  token_ref TEXT NOT NULL REFERENCES billing_purchases(token_ref) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`.trim();

/**
 * Atomic file-backed store for purchase records and install entitlements.
 *
 * Keyed by `tokenRef(purchaseToken)` rather than raw purchase tokens so the on-disk
 * store never persists bearer-equivalent Play tokens in cleartext.
 *
 * Writes go through a sibling `.tmp` file + `fs.renameSync` so a crash mid-write
 * cannot leave a half-written JSON file, and a corrupt existing file is
 * quarantined to `<file>.corrupt.<timestamp>` rather than silently crashing or
 * overwriting forensic evidence.
 */
class BillingStore {
  constructor(filePath) {
    this.filePath = filePath;
    this.state = { purchases: {}, installs: {} };
    this._load();
  }

  _load() {
    if (!this.filePath || !fs.existsSync(this.filePath)) return;
    const raw = fs.readFileSync(this.filePath, 'utf8');
    if (!raw.trim()) return;
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object' && parsed.purchases && parsed.installs) {
        this.state = {
          purchases: { ...parsed.purchases },
          installs: { ...parsed.installs },
        };
        return;
      }
      throw new Error('Malformed store root');
    } catch (_) {
      const quarantine = `${this.filePath}.corrupt.${Date.now()}`;
      fs.renameSync(this.filePath, quarantine);
      this.state = { purchases: {}, installs: {} };
      this._persist();
    }
  }

  _persist() {
    if (!this.filePath) return;
    const dir = path.dirname(this.filePath);
    fs.mkdirSync(dir, { recursive: true });
    const tmp = `${this.filePath}.tmp.${process.pid}`;
    fs.writeFileSync(tmp, JSON.stringify(this.state, null, 2), 'utf8');
    fs.renameSync(tmp, this.filePath);
  }

  upsertPurchase({
    purchaseToken,
    productId,
    packageName,
    status = 'active',
    expiresAt,
    trialEndsAt,
    autoRenew,
    inGracePeriod,
    installId,
  }) {
    const key = tokenRef(purchaseToken);
    const prev = this.state.purchases[key] || {};
    const record = {
      tokenRef: key,
      productId: productId ?? prev.productId,
      packageName: packageName ?? prev.packageName,
      status,
      // Never blank a stored expiry when an RTDN event (such as SUBSCRIPTION_CANCELED)
      // omits a new expiry timestamp.
      expiresAt: expiresAt !== undefined ? expiresAt : (prev.expiresAt ?? null),
      trialEndsAt: trialEndsAt !== undefined ? trialEndsAt : (prev.trialEndsAt ?? null),
      autoRenew: autoRenew !== undefined ? autoRenew : (prev.autoRenew ?? null),
      inGracePeriod: inGracePeriod !== undefined ? Boolean(inGracePeriod) : Boolean(prev.inGracePeriod),
      updatedAt: new Date().toISOString(),
    };
    this.state.purchases[key] = record;

    if (installId && status === 'active') {
      const installKey = tokenRef(installId, 'track-pro-install-ref-v1');
      this.state.installs[installKey] = {
        installRef: installKey,
        tokenRef: key,
        productId: record.productId,
        updatedAt: record.updatedAt,
      };
    }
    this._persist();
    return record;
  }

  getPurchase(purchaseToken) {
    return this.state.purchases[tokenRef(purchaseToken)] || null;
  }

  revokeByToken(purchaseToken, { packageName, reason = 'revoked' } = {}) {
    const key = tokenRef(purchaseToken);
    const existing = this.state.purchases[key];
    if (!existing) return false;
    if (packageName && existing.packageName && existing.packageName !== packageName) {
      return false;
    }
    delete this.state.purchases[key];
    for (const [installKey, entry] of Object.entries(this.state.installs)) {
      if (entry.tokenRef === key) {
        delete this.state.installs[installKey];
      }
    }
    this._persist();
    return true;
  }

  purchaseCount() {
    return Object.keys(this.state.purchases).length;
  }

  installCount() {
    return Object.keys(this.state.installs).length;
  }
}

BillingStore.POSTGRES_DDL = POSTGRES_DDL;

module.exports = { BillingStore, POSTGRES_DDL };
