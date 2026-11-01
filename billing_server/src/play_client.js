'use strict';

/**
 * Minimal, dependency-free Google Play Developer API client for the purchase
 * verification service.
 *
 * The verifier (`./verifier.js`) expects exactly two methods:
 *
 *   getSubscriptionV2({ packageName, productId, purchaseToken })
 *   getProduct({ packageName, productId, purchaseToken })
 *
 * This file implements them against the public REST API using a service-account
 * JWT (RS256) and Node's built-in `https`/`crypto`. No `googleapis` dependency is
 * introduced, which keeps the service's zero-runtime-dependency property.
 *
 * Security properties:
 *   - The purchase token is only ever placed in the URL path, which is what the
 *     Play API requires. It is never logged by this module. Errors carry a
 *     status code and a generic message, never the URL.
 *   - The service-account private key is read from disk and never logged.
 *   - The access token is cached in memory and refreshed 60s before expiry.
 *   - Network/timeout failures are surfaced as retryable unavailability, not as
 *     a rejection. The verifier decides what that means.
 */

const crypto = require('node:crypto');
const fs = require('node:fs');
const https = require('node:https');

const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const DEFAULT_TIMEOUT_MS = 10_000;
const TOKEN_REFRESH_SKEW_MS = 60_000;

function base64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * A transport may throw anything (socket error, timeout, DNS). Normalize it to
 * a retryable unavailability unless it already carries a Play status/code.
 * The original error is attached as `cause` for debugging but is not logged by
 * this module.
 */
function normalizeTransportError(err) {
  if (err && (err.code === 'play_unreachable' || typeof err.statusCode === 'number')) {
    return err;
  }
  return Object.assign(new Error('Play API request failed'), {
    code: 'play_unreachable',
    cause: err,
  });
}

/**
 * Default transport. Returns `{ statusCode, body }` where `body` is parsed JSON
 * when possible. Rejects with `{ code: 'play_unreachable' }` on timeout or a
 * socket error, and never includes the URL (which carries the purchase token)
 * in the error message.
 */
function defaultRequest(url, options = {}) {
  const { method = 'GET', headers = {}, body = null, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const req = https.request(
      {
        protocol: parsed.protocol,
        hostname: parsed.hostname,
        port: parsed.port || undefined,
        path: `${parsed.pathname}${parsed.search}`,
        method,
        headers,
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const raw = Buffer.concat(chunks).toString('utf8');
          let parsedBody = raw;
          try {
            parsedBody = raw ? JSON.parse(raw) : {};
          } catch (_) {
            // Keep the raw text; callers only need the status code.
          }
          resolve({ statusCode: res.statusCode || 0, body: parsedBody });
        });
      },
    );

    req.setTimeout(timeoutMs, () => {
      req.destroy(Object.assign(new Error('Play API request timed out'), { code: 'play_unreachable' }));
    });
    req.on('error', (err) => {
      reject(Object.assign(new Error('Play API request failed'), { code: 'play_unreachable', cause: err }));
    });
    if (body) req.write(body);
    req.end();
  });
}

/**
 * Create a Play Developer API client from a parsed service-account JSON object.
 *
 * @param {object} options
 * @param {object} options.credentials  Parsed service-account key (client_email,
 *                                      private_key, optional token_uri).
 * @param {string} [options.tokenEndpoint]
 * @param {string} [options.apiBase]
 * @param {string} [options.scope]
 * @param {() => number} [options.now]
 * @param {(url: string, options: object) => Promise<{statusCode:number, body:any}>} [options.request]
 * @param {number} [options.timeoutMs]
 */
function createPlayClient({
  credentials,
  tokenEndpoint = TOKEN_ENDPOINT,
  apiBase = API_BASE,
  scope = SCOPE,
  now = () => Date.now(),
  request = defaultRequest,
  timeoutMs = DEFAULT_TIMEOUT_MS,
}) {
  if (!credentials || typeof credentials !== 'object') {
    throw new Error('credentials are required');
  }
  if (typeof credentials.client_email !== 'string' || !credentials.client_email) {
    throw new Error('credentials.client_email is required');
  }
  if (typeof credentials.private_key !== 'string' || !credentials.private_key) {
    throw new Error('credentials.private_key is required');
  }

  // A JSON service-account key stores newlines escaped as \n. Undo that before
  // handing the key to the signer.
  const privateKey = credentials.private_key.replace(/\\n/g, '\n');
  let cachedToken = null;
  let cachedExpiresAtMs = 0;

  async function getAccessToken() {
    const nowMs = now();
    if (cachedToken && cachedExpiresAtMs - TOKEN_REFRESH_SKEW_MS > nowMs) {
      return cachedToken;
    }

    const iat = Math.floor(nowMs / 1000);
    const header = { alg: 'RS256', typ: 'JWT' };
    const payload = {
      iss: credentials.client_email,
      scope,
      aud: tokenEndpoint,
      iat,
      exp: iat + 3600,
    };
    const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
    const signer = crypto.createSign('RSA-SHA256');
    signer.update(signingInput);
    const signature = signer.sign(privateKey);
    const assertion = `${signingInput}.${base64url(signature)}`;

    const form = new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    });

    let res;
    try {
      res = await request(tokenEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(form.toString()),
        },
        body: form.toString(),
        timeoutMs,
      });
    } catch (err) {
      throw normalizeTransportError(err);
    }

    if (res.statusCode !== 200 || !res.body || typeof res.body.access_token !== 'string') {
      throw Object.assign(new Error('Play OAuth token exchange failed'), {
        code: 'play_unreachable',
        statusCode: res.statusCode,
      });
    }

    const expiresIn = Number(res.body.expires_in);
    cachedToken = res.body.access_token;
    cachedExpiresAtMs = nowMs + (Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : 3600) * 1000;
    return cachedToken;
  }

  async function apiGet(path) {
    const token = await getAccessToken();
    let res;
    try {
      res = await request(`${apiBase}${path}`, {
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
        timeoutMs,
      });
    } catch (err) {
      throw normalizeTransportError(err);
    }

    if (res.statusCode === 404 || res.statusCode === 410) {
      throw Object.assign(new Error('Play purchase not found'), {
        code: 'token_not_found',
        statusCode: res.statusCode,
      });
    }
    if (res.statusCode === 400) {
      throw Object.assign(new Error('Play rejected the purchase token'), {
        code: 'invalid_token',
        statusCode: res.statusCode,
      });
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Object.assign(new Error('Play API request failed'), {
        code: 'play_api_error',
        statusCode: res.statusCode,
      });
    }
    return res.body;
  }

  return {
    async getSubscriptionV2({ packageName, productId, purchaseToken }) {
      const path =
        `/applications/${encodeURIComponent(packageName)}` +
        `/purchases/subscriptionsv2/${encodeURIComponent(productId)}` +
        `/tokens/${encodeURIComponent(purchaseToken)}`;
      return apiGet(path);
    },

    async getProduct({ packageName, productId, purchaseToken }) {
      const path =
        `/applications/${encodeURIComponent(packageName)}` +
        `/purchases/products/${encodeURIComponent(productId)}` +
        `/tokens/${encodeURIComponent(purchaseToken)}`;
      return apiGet(path);
    },
  };
}

/**
 * Build a client from the standard `GOOGLE_APPLICATION_CREDENTIALS` path, or
 * from `GOOGLE_APPLICATION_CREDENTIALS_JSON` for platforms that inject the key
 * as an environment value. The file path is preferred.
 */
function createPlayClientFromEnv(env = process.env, overrides = {}) {
  const raw =
    env.GOOGLE_APPLICATION_CREDENTIALS_JSON ||
    (env.GOOGLE_APPLICATION_CREDENTIALS
      ? fs.readFileSync(env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')
      : null);

  if (!raw) {
    throw new Error(
      'GOOGLE_APPLICATION_CREDENTIALS (path) or GOOGLE_APPLICATION_CREDENTIALS_JSON is required',
    );
  }

  let credentials;
  try {
    credentials = JSON.parse(raw);
  } catch (_) {
    throw new Error('Play service-account credentials are not valid JSON');
  }

  return createPlayClient({ credentials, ...overrides });
}

module.exports = {
  createPlayClient,
  createPlayClientFromEnv,
  defaultRequest,
  TOKEN_ENDPOINT,
  API_BASE,
  SCOPE,
};
