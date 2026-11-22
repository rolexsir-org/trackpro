'use strict';

/**
 * Verification of Google Cloud Pub/Sub **authenticated push** OIDC JWTs.
 *
 * When a push subscription is configured for Google-managed OIDC, Pub/Sub
 * attaches `Authorization: Bearer <JWT>` where the JWT is signed by Google with
 * the project's Pub/Sub service-account key. We verify it without any external
 * dependency (only `node:crypto` + the project's own `node:https` helper):
 *
 *   - signature against Google's rotated public certs (fetched from
 *     https://www.googleapis.com/oauth2/v3/certs, keyed by the token `kid`);
 *   - `iss` is a Google accounts issuer;
 *   - `aud` equals the configured `TRACK_RTDN_AUDIENCE`;
 *   - `exp` is not in the past (small clock-skew allowance);
 *   - `iat` is not in the future;
 *   - optionally `email`/`sub` equals the expected Pub/Sub service account.
 *
 * Safe coexistence: a request whose bearer is *not* a JWT still falls back to the
 * static `TRACK_RTDN_SECRET` path, so operators can migrate gradually. But a
 * token that *is* a JWT is only accepted if it passes OIDC verification — it is
 * never silently downgraded to the shared secret.
 *
 * This module never logs tokens, claims, or certificate material; callers log
 * only an opaque `rtdn_auth_failed` outcome.
 */

const crypto = require('node:crypto');
const { defaultRequest } = require('./play_client');

const GOOGLE_CERTS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
// Google issues OIDC tokens with either form.
const DEFAULT_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];

function b64urlToBuffer(value) {
  return Buffer.from(value, 'base64url');
}

function b64urlDecodeJson(value) {
  return JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
}

function isJwt(token) {
  if (typeof token !== 'string') return false;
  const parts = token.split('.');
  return parts.length === 3 && parts[0].length > 0 && parts[1].length > 0 && parts[2].length > 0;
}

function audienceMatches(aud, expected) {
  if (Array.isArray(aud)) return aud.includes(expected);
  return aud === expected;
}

class OidcVerifier {
  constructor({
    audience,
    expectedEmail = null,
    issuer = DEFAULT_ISSUERS,
    certsUrl = GOOGLE_CERTS_URL,
    certsProvider = null,
    clockSkewSeconds = 60,
    now = () => Math.floor(Date.now() / 1000),
    request = defaultRequest,
  } = {}) {
    if (!audience || typeof audience !== 'string' || !audience.trim()) {
      throw new Error('OidcVerifier requires a non-empty audience');
    }
    this.audience = audience;
    this.expectedEmail = expectedEmail || null;
    this.issuers = Array.isArray(issuer) ? issuer : [issuer];
    this.certsUrl = certsUrl;
    this.certsProvider = typeof certsProvider === 'function' ? certsProvider : null;
    this.clockSkewSeconds = clockSkewSeconds;
    this.now = now;
    this.request = request;
    this._cache = null; // { expiresAt, certs: Map<kid, pem> }
  }

  async _getCert(kid) {
    if (this.certsProvider) {
      const provided = await this.certsProvider(kid);
      return typeof provided === 'string' ? provided : null;
    }
    const nowSec = this.now();
    if (!this._cache || this._cache.expiresAt <= nowSec) {
      const res = await this.request(this.certsUrl, { method: 'GET', headers: {}, timeoutMs: 5000 });
      if (res.statusCode !== 200 || !res.body || typeof res.body !== 'object') {
        throw Object.assign(new Error('Failed to fetch Google OIDC signing certificates'), {
          code: 'oidc_certs_unavailable',
        });
      }
      const certs = new Map();
      for (const [key, pem] of Object.entries(res.body)) {
        if (typeof pem === 'string') certs.set(key, pem);
      }
      this._cache = { expiresAt: nowSec + 3600, certs };
    }
    return this._cache.certs.get(kid) || null;
  }

  /**
   * Returns true only when the token is a structurally valid, properly signed
   * Google OIDC JWT whose standard claims match the configured policy. Any
   * failure (bad shape, bad signature, wrong issuer/audience/expiry/email,
   * missing cert) returns false — never throws for an untrusted input.
   */
  async verify(token) {
    if (!isJwt(token)) return false;

    let header;
    let payload;
    let signature;
    try {
      const parts = token.split('.');
      header = b64urlDecodeJson(parts[0]);
      payload = b64urlDecodeJson(parts[1]);
      signature = b64urlToBuffer(parts[2]);
    } catch (_) {
      return false;
    }

    if (header.alg !== 'RS256') return false;
    const kid = header.kid;
    if (typeof kid !== 'string' || !kid) return false;

    const cert = await this._getCert(kid);
    if (typeof cert !== 'string') return false;
    let key;
    try {
      key = crypto.createPublicKey(cert);
    } catch (_) {
      return false;
    }

    const signingInput = `${token.split('.')[0]}.${token.split('.')[1]}`;
    let sigOk = false;
    try {
      sigOk = crypto.verify('sha256', Buffer.from(signingInput, 'utf8'), key, signature);
    } catch (_) {
      sigOk = false;
    }
    if (!sigOk) return false;

    const nowSec = this.now();
    if (!this.issuers.includes(payload.iss)) return false;
    if (!audienceMatches(payload.aud, this.audience)) return false;
    if (typeof payload.exp !== 'number' || payload.exp < nowSec - this.clockSkewSeconds) return false;
    if (typeof payload.iat === 'number' && payload.iat > nowSec + this.clockSkewSeconds) return false;
    if (this.expectedEmail) {
      const email = typeof payload.email === 'string' ? payload.email : payload.sub;
      if (email !== this.expectedEmail) return false;
    }
    return true;
  }
}

/**
 * Build an OIDC verifier from the environment. Returns `null` (disabled) when
 * `TRACK_RTDN_AUDIENCE` is not set, so the caller can fall back to the static
 * shared secret. This is the bridge used by the production entry point.
 */
function createOidcVerifier(env = process.env, overrides = {}) {
  const audience = env.TRACK_RTDN_AUDIENCE;
  if (!audience || !String(audience).trim()) return null;
  return new OidcVerifier({
    audience: String(audience).trim(),
    expectedEmail: env.TRACK_RTDN_EXPECTED_EMAIL ? String(env.TRACK_RTDN_EXPECTED_EMAIL).trim() : null,
    issuer: env.TRACK_RTDN_ISSUER ? env.TRACK_RTDN_ISSUER : DEFAULT_ISSUERS,
    ...overrides,
  });
}

module.exports = {
  OidcVerifier,
  createOidcVerifier,
  isJwt,
  audienceMatches,
  GOOGLE_CERTS_URL,
  DEFAULT_ISSUERS,
};
