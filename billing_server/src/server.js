'use strict';

const http = require('node:http');
const {
  verifyBearerHeader,
  tokenRef,
  createLogger,
  RateLimiter,
} = require('./security');
const { handleRtdn } = require('./rtdn');

const DEFAULT_MAX_BODY_BYTES = 16 * 1024;

function readJsonBody(req, maxBytes = DEFAULT_MAX_BODY_BYTES) {
  return new Promise((resolve, reject) => {
    let total = 0;
    let tooLarge = false;
    const chunks = [];

    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        tooLarge = true;
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (tooLarge) {
        const err = new Error('Payload too large');
        err.statusCode = 413;
        reject(err);
        return;
      }
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw.trim()) {
        const err = new Error('Empty JSON body');
        err.statusCode = 400;
        reject(err);
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (_) {
        const err = new Error('Malformed JSON');
        err.statusCode = 400;
        reject(err);
      }
    });

    req.on('error', reject);
  });
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

/**
 * Creates the Track Pro billing verification HTTP server (`POST /billing/verify`,
 * `POST /rtdn`, `GET /healthz`).
 */
function createBillingServer({
  verifier,
  store,
  apiKeys = [],
  rtdnSecret = null,
  integrityVerifier = null,
  rateLimiter = new RateLimiter(),
  logger = createLogger(),
  maxBodyBytes = DEFAULT_MAX_BODY_BYTES,
}) {
  if (!verifier) throw new Error('verifier is required');
  if (!store) throw new Error('store is required');

  return http.createServer(async (req, res) => {
    const url = new URL(req.url || '/', 'http://localhost');
    const clientIp = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'anon')
      .toString()
      .split(',')[0]
      .trim();

    if (req.method === 'GET' && url.pathname === '/healthz') {
      sendJson(res, 200, { ok: true });
      return;
    }

    if (!rateLimiter.allow(clientIp)) {
      logger.log('rate_limited', { path: url.pathname });
      sendJson(res, 429, { valid: false, retryable: true, reason: 'rate_limited' });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/billing/verify') {
      if (!verifyBearerHeader(req.headers.authorization, apiKeys)) {
        logger.log('auth_failed', { path: '/billing/verify' });
        sendJson(res, 401, { valid: false, reason: 'unauthorized' });
        return;
      }

      if (integrityVerifier) {
        const integrityToken = req.headers['x-integrity-token'];
        const ok = await integrityVerifier(integrityToken);
        if (!ok) {
          logger.log('integrity_failed', { path: '/billing/verify' });
          sendJson(res, 403, { valid: false, reason: 'integrity_failed' });
          return;
        }
      }

      let body;
      try {
        body = await readJsonBody(req, maxBodyBytes);
      } catch (err) {
        const code = err.statusCode || 400;
        sendJson(res, code, { valid: false, reason: code === 413 ? 'payload_too_large' : 'bad_request' });
        return;
      }

      const { productId, purchaseToken, packageName, installId } = body || {};
      if (
        typeof productId !== 'string' ||
        typeof purchaseToken !== 'string' ||
        typeof packageName !== 'string' ||
        !productId ||
        !purchaseToken ||
        !packageName
      ) {
        sendJson(res, 400, { valid: false, reason: 'missing_fields' });
        return;
      }

      const ref = tokenRef(purchaseToken);
      const verdict = await verifier.verify({ productId, purchaseToken, packageName });

      if (verdict.retryable) {
        logger.log('verify_unavailable', { productId, tokenRef: ref, reason: verdict.reason });
        sendJson(res, 503, { valid: false, retryable: true, reason: verdict.reason || 'play_unreachable' });
        return;
      }

      if (verdict.valid) {
        store.upsertPurchase({
          purchaseToken,
          productId,
          packageName,
          status: 'active',
          expiresAt: verdict.expiresAt,
          trialEndsAt: verdict.trialEndsAt,
          autoRenew: verdict.autoRenew,
          inGracePeriod: verdict.inGracePeriod,
          installId,
        });
        logger.log('verify_ok', { productId, tokenRef: ref });
        sendJson(res, 200, {
          valid: true,
          expiresAt: verdict.expiresAt,
          trialEndsAt: verdict.trialEndsAt,
          autoRenew: verdict.autoRenew,
          inGracePeriod: Boolean(verdict.inGracePeriod),
        });
        return;
      }

      if (verdict.pending) {
        logger.log('verify_pending', { productId, tokenRef: ref });
        sendJson(res, 200, {
          valid: false,
          pending: true,
          expiresAt: verdict.expiresAt || null,
          reason: 'pending',
        });
        return;
      }

      logger.log('verify_rejected', { productId, tokenRef: ref, reason: verdict.reason });
      sendJson(res, 200, {
        valid: false,
        reason: verdict.reason || 'rejected',
      });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/rtdn') {
      if (rtdnSecret && !verifyBearerHeader(req.headers.authorization, [rtdnSecret])) {
        sendJson(res, 401, { ok: false, reason: 'unauthorized' });
        return;
      }
      let body;
      try {
        body = await readJsonBody(req, maxBodyBytes);
        const outcome = await handleRtdn(body, { store, verifier });
        logger.log('rtdn_processed', { action: outcome.action, type: outcome.type });
        sendJson(res, 200, { ok: true, ...outcome });
      } catch (err) {
        const code = err.statusCode || 400;
        logger.log('rtdn_bad_request', { code });
        sendJson(res, code, { ok: false, reason: 'invalid_rtdn' });
      }
      return;
    }

    sendJson(res, 404, { ok: false, reason: 'not_found' });
  });
}

module.exports = { createBillingServer, readJsonBody };
