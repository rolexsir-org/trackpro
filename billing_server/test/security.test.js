'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  verifyBearerHeader,
  tokenRef,
  redact,
  createLogger,
  sanitizePlayError,
  RateLimiter,
} = require('../src/security');

test('security.1: valid bearer matches configured single key', () => {
  assert.equal(verifyBearerHeader('Bearer prod_key_alpha', ['prod_key_alpha']), true);
});

test('security.2: valid bearer matches second key during key rotation', () => {
  assert.equal(verifyBearerHeader('Bearer prod_key_beta', ['prod_key_alpha', 'prod_key_beta']), true);
});

test('security.3: missing, malformed, or wrong-scheme authorization header is rejected', () => {
  assert.equal(verifyBearerHeader(undefined, ['prod_key_alpha']), false);
  assert.equal(verifyBearerHeader('', ['prod_key_alpha']), false);
  assert.equal(verifyBearerHeader('Basic prod_key_alpha', ['prod_key_alpha']), false);
  assert.equal(verifyBearerHeader('Bearer wrong_key', ['prod_key_alpha']), false);
});

test('security.4: empty or blank configured key authenticates nothing', () => {
  assert.equal(verifyBearerHeader('Bearer anything', []), false);
  assert.equal(verifyBearerHeader('Bearer anything', ['   ', '']), false);
});

test('security.5: rate limiter enforces burst capacity and refills over time', () => {
  let clock = 1_000_000;
  const limiter = new RateLimiter({ capacity: 2, refillPerSec: 1, now: () => clock });
  assert.equal(limiter.allow('ip1'), true);
  assert.equal(limiter.allow('ip1'), true);
  assert.equal(limiter.allow('ip1'), false);
  clock += 1000;
  assert.equal(limiter.allow('ip1'), true);
});

test('security.6: rate limiter isolates buckets per client key', () => {
  const limiter = new RateLimiter({ capacity: 1, refillPerSec: 0 });
  assert.equal(limiter.allow('ip1'), true);
  assert.equal(limiter.allow('ip1'), false);
  assert.equal(limiter.allow('ip2'), true);
});

test('security.7: tokenRef is deterministic, fixed-width, and non-reversible', () => {
  const raw = 'purchase_token_super_secret_value_1234567890';
  const r1 = tokenRef(raw);
  const r2 = tokenRef(raw);
  assert.equal(r1, r2);
  assert.match(r1, /^tok_[0-9a-f]{16}$/);
  assert.equal(r1.includes('secret'), false);
});

test('security.8: tokenRef handles empty input safely', () => {
  assert.equal(tokenRef(''), 'tok_empty');
  assert.equal(tokenRef(null), 'tok_empty');
});

test('security.9: redact scrubs sensitive keys at depth including installId and email', () => {
  const input = {
    productId: 'track_pro_annual',
    purchaseToken: 'raw_token_value',
    nested: {
      installId: 'inst_999',
      email: 'user@example.com',
      note: 'contact user@example.com',
    },
  };
  const out = redact(input);
  assert.equal(out.productId, 'track_pro_annual');
  assert.equal(out.purchaseToken, '[redacted]');
  assert.equal(out.nested.installId, '[redacted]');
  assert.equal(out.nested.email, '[redacted]');
  assert.equal(out.nested.note.includes('user@example.com'), false);
});

test('security.10: redact handles cyclic structures without throwing', () => {
  const a = { name: 'node' };
  a.self = a;
  const out = redact(a);
  assert.equal(out.name, 'node');
  assert.equal(out.self, '[Circular]');
});

test('security.11: logger emits one JSON line per event and scrubs embedded tokens', () => {
  const lines = [];
  const logger = createLogger((l) => lines.push(l));
  logger.log('verify_failed', {
    msg: 'GET /tokens/abcdefghijklmnopqrstuvwxyz0123456789 failed',
  });
  assert.equal(lines.length, 1);
  assert.equal(lines[0].includes('abcdefghijklmnopqrstuvwxyz0123456789'), false);
  const parsed = JSON.parse(lines[0]);
  assert.equal(parsed.event, 'verify_failed');
});

test('security.12: sanitizePlayError drops cause and scrubs token from message', () => {
  const rawToken = 'play_secret_token_9876543210abcdefghijklmnop';
  const cause = new Error(`URL https://androidpublisher.googleapis.com/.../${rawToken}`);
  const outer = new Error(`Play API failed for ${rawToken}`, { cause });
  outer.statusCode = 502;
  const safe = sanitizePlayError(outer);
  assert.equal(safe.cause, undefined);
  assert.equal(safe.message.includes(rawToken), false);
  assert.equal(safe.statusCode, 502);
});

test('security.13: redact scrubs Bearer headers inside free-form strings', () => {
  const out = redact({ header: 'Bearer secret_api_key_value_123' });
  assert.equal(out.header, 'Bearer [redacted]');
});
