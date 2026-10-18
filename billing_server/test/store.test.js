'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { BillingStore, POSTGRES_DDL } = require('../src/store');

function tmpFile() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'track-store-'));
  return path.join(dir, 'store.json');
}

test('store.1: upsertPurchase is idempotent by purchaseToken', () => {
  const store = new BillingStore(tmpFile());
  store.upsertPurchase({
    purchaseToken: 'tok_alpha_12345678',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
    expiresAt: '2027-01-01T00:00:00.000Z',
    installId: 'inst_1',
  });
  store.upsertPurchase({
    purchaseToken: 'tok_alpha_12345678',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
    expiresAt: '2027-01-01T00:00:00.000Z',
    installId: 'inst_1',
  });
  assert.equal(store.purchaseCount(), 1);
  assert.equal(store.installCount(), 1);
});

test('store.2: persisted state survives a process restart', () => {
  const file = tmpFile();
  const s1 = new BillingStore(file);
  s1.upsertPurchase({
    purchaseToken: 'tok_persist_12345678',
    productId: 'track_pro_monthly',
    packageName: 'com.track.app',
    expiresAt: '2027-02-01T00:00:00.000Z',
  });

  const s2 = new BillingStore(file);
  const rec = s2.getPurchase('tok_persist_12345678');
  assert.ok(rec);
  assert.equal(rec.productId, 'track_pro_monthly');
});

test('store.3: atomic write leaves no .tmp file behind and stores no raw token', () => {
  const file = tmpFile();
  const store = new BillingStore(file);
  store.upsertPurchase({
    purchaseToken: 'raw_secret_token_never_on_disk',
    productId: 'track_pro_lifetime',
    packageName: 'com.track.app',
  });
  const dirEntries = fs.readdirSync(path.dirname(file));
  assert.equal(dirEntries.some((n) => n.includes('.tmp.')), false);
  const diskText = fs.readFileSync(file, 'utf8');
  assert.equal(diskText.includes('raw_secret_token_never_on_disk'), false);
});

test('store.4: corrupt store file is quarantined rather than crashing or losing evidence', () => {
  const file = tmpFile();
  fs.writeFileSync(file, '{not-valid-json', 'utf8');
  const store = new BillingStore(file);
  assert.equal(store.purchaseCount(), 0);
  const dirEntries = fs.readdirSync(path.dirname(file));
  assert.equal(dirEntries.some((n) => n.includes('.corrupt.')), true);
});

test('store.5: revoking one token drops its install entitlement and leaves others intact', () => {
  const store = new BillingStore(tmpFile());
  store.upsertPurchase({
    purchaseToken: 'tok_one_12345678',
    productId: 'track_pro_monthly',
    packageName: 'com.track.app',
    installId: 'inst_one',
  });
  store.upsertPurchase({
    purchaseToken: 'tok_two_12345678',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
    installId: 'inst_two',
  });
  assert.equal(store.revokeByToken('tok_one_12345678'), true);
  assert.equal(store.getPurchase('tok_one_12345678'), null);
  assert.ok(store.getPurchase('tok_two_12345678'));
  assert.equal(store.installCount(), 1);
});

test('store.6: revoking an unknown token is a safe no-op', () => {
  const store = new BillingStore(tmpFile());
  assert.equal(store.revokeByToken('tok_missing_12345678'), false);
});

test('store.7: an update without expiresAt preserves the previously stored expiry', () => {
  const store = new BillingStore(tmpFile());
  store.upsertPurchase({
    purchaseToken: 'tok_keep_expiry_123',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
    expiresAt: '2027-05-01T00:00:00.000Z',
    autoRenew: true,
  });
  store.upsertPurchase({
    purchaseToken: 'tok_keep_expiry_123',
    autoRenew: false,
  });
  const rec = store.getPurchase('tok_keep_expiry_123');
  assert.equal(rec.expiresAt, '2027-05-01T00:00:00.000Z');
  assert.equal(rec.autoRenew, false);
});

test('store.8: cross-package revoke is refused', () => {
  const store = new BillingStore(tmpFile());
  store.upsertPurchase({
    purchaseToken: 'tok_pkg_12345678',
    productId: 'track_pro_annual',
    packageName: 'com.track.app',
  });
  assert.equal(store.revokeByToken('tok_pkg_12345678', { packageName: 'com.other.app' }), false);
  assert.ok(store.getPurchase('tok_pkg_12345678'));
});

test('store.9: Postgres DDL defines both tables and foreign key cascade', () => {
  assert.match(POSTGRES_DDL, /CREATE TABLE IF NOT EXISTS billing_purchases/);
  assert.match(POSTGRES_DDL, /CREATE TABLE IF NOT EXISTS billing_install_entitlements/);
  assert.match(POSTGRES_DDL, /ON DELETE CASCADE/);
});

test('store.10: in-memory mode works when filePath is omitted', () => {
  const store = new BillingStore(null);
  store.upsertPurchase({
    purchaseToken: 'tok_mem_12345678',
    productId: 'track_pro_lifetime',
    packageName: 'com.track.app',
  });
  assert.equal(store.purchaseCount(), 1);
});
