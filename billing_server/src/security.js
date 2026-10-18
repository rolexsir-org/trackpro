'use strict';

const crypto = require('node:crypto');

/**
 * Constant-time comparison of an incoming `Authorization: Bearer <token>` header
 * against one or more configured API keys (supporting zero-downtime key rotation).
 *
 * Empty configured keys authenticate nothing, and length differences are hashed
 * first so timingSafeEqual never leaks key length.
 */
function verifyBearerHeader(authHeader, configuredKeys) {
  if (typeof authHeader !== 'string') return false;
  const match = /^Bearer\s+(\S+)$/.exec(authHeader.trim());
  if (!match) return false;
  const candidate = match[1];
  const keys = (Array.isArray(configuredKeys) ? configuredKeys : [configuredKeys])
    .filter((k) => typeof k === 'string' && k.trim().length > 0)
    .map((k) => k.trim());
  if (keys.length === 0) return false;

  const candidateHash = crypto.createHash('sha256').update(candidate, 'utf8').digest();
  let matched = false;
  for (const key of keys) {
    const keyHash = crypto.createHash('sha256').update(key, 'utf8').digest();
    if (crypto.timingSafeEqual(candidateHash, keyHash)) {
      matched = true;
    }
  }
  return matched;
}

/**
 * Stable, non-reversible reference for a purchase token so logs and support
 * lines can correlate requests without ever recording the bearer-equivalent
 * Play purchase token.
 */
function tokenRef(token, salt = 'track-pro-token-ref-v1') {
  if (typeof token !== 'string' || token.length === 0) return 'tok_empty';
  const digest = crypto.createHmac('sha256', salt).update(token, 'utf8').digest('hex');
  return `tok_${digest.slice(0, 16)}`;
}

const SENSITIVE_KEY_RE = /token|secret|password|authorization|cookie|key|credential|installid|install_id|email/i;
const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const LONG_TOKEN_RE = /\b[A-Za-z0-9._\-+/=]{24,}\b/g;

function scrubText(text) {
  if (typeof text !== 'string') return text;
  return text
    .replace(EMAIL_RE, '[redacted-email]')
    .replace(/Bearer\s+\S+/gi, 'Bearer [redacted]')
    .replace(LONG_TOKEN_RE, '[redacted-token]');
}

/**
 * Deep-redacts sensitive keys, email addresses, and token-shaped strings while
 * surviving cyclic object graphs.
 */
function redact(value, seen = new WeakSet()) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'string') return scrubText(value);
  if (typeof value !== 'object') return value;
  if (seen.has(value)) return '[Circular]';
  seen.add(value);

  if (Array.isArray(value)) {
    return value.map((item) => redact(item, seen));
  }
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SENSITIVE_KEY_RE.test(k)) {
      out[k] = '[redacted]';
    } else {
      out[k] = redact(v, seen);
    }
  }
  return out;
}

/**
 * Structured single-line JSON logger with automatic redaction.
 */
function createLogger(sink = (line) => process.stdout.write(`${line}\n`)) {
  return {
    log(event, fields = {}) {
      const safe = redact({ ts: new Date().toISOString(), event, ...fields });
      sink(JSON.stringify(safe));
    },
  };
}

/**
 * Strips the original `cause` and scrubs any URL path or message that could
 * carry a Play purchase token before an error crosses a log or catch boundary.
 */
function sanitizePlayError(err, code = 'play_api_error') {
  const rawMessage = err && typeof err.message === 'string' ? err.message : String(err ?? 'unknown');
  const safe = new Error(scrubText(rawMessage));
  safe.code = (err && err.code) || code;
  safe.statusCode = err && typeof err.statusCode === 'number' ? err.statusCode : undefined;
  return safe;
}

/**
 * Per-client token-bucket rate limiter.
 */
class RateLimiter {
  constructor({ capacity = 20, refillPerSec = 2, now = () => Date.now() } = {}) {
    this.capacity = capacity;
    this.refillPerSec = refillPerSec;
    this.now = now;
    this.buckets = new Map();
  }

  allow(clientKey = 'anon') {
    const t = this.now();
    let b = this.buckets.get(clientKey);
    if (!b) {
      b = { tokens: this.capacity, lastMs: t };
      this.buckets.set(clientKey, b);
    } else {
      const elapsedSec = Math.max(0, (t - b.lastMs) / 1000);
      b.tokens = Math.min(this.capacity, b.tokens + elapsedSec * this.refillPerSec);
      b.lastMs = t;
    }
    if (b.tokens < 1) return false;
    b.tokens -= 1;
    return true;
  }
}

module.exports = {
  verifyBearerHeader,
  tokenRef,
  scrubText,
  redact,
  createLogger,
  sanitizePlayError,
  RateLimiter,
};
