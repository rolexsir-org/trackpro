'use strict';

/**
 * Production entry point for the Track Pro billing verification service.
 *
 * `src/server.js` is the HTTP factory (used by the tests). This file is the
 * process: it reads the deployment configuration, constructs the real Play
 * Developer API client and file-backed store, starts the server, and handles
 * graceful shutdown.
 *
 * Required environment:
 *   TRACK_BILLING_API_KEYS        comma-separated bearer keys for /billing/verify
 *   TRACK_RTDN_SECRET             bearer token for /rtdn (Pub/Sub push)
 *   TRACK_STORE_PATH              path to the persistent JSON purchase store
 *   GOOGLE_APPLICATION_CREDENTIALS  path to the Play service-account JSON key
 *   PORT                          listening port (default 8080)
 *
 * The service refuses to start if any of the first four is missing. A billing
 * service that silently starts without authentication is worse than one that
 * does not start: it would accept forged purchase tokens.
 */

const { createBillingServer } = require('./server');
const { BillingStore } = require('./store');
const { PlayPurchaseVerifier } = require('./verifier');
const { RateLimiter, createLogger } = require('./security');
const { createPlayClientFromEnv } = require('./play_client');

function parseApiKeys(value) {
  return String(value || '')
    .split(',')
    .map((key) => key.trim())
    .filter((key) => key.length > 0);
}

/**
 * Build the service without listening. Exposed so tests can inject a fake Play
 * client and a temporary store.
 */
function createService({
  env = process.env,
  playClient = undefined,
  store = undefined,
  verifier = undefined,
  logger = createLogger(),
  rateLimiter = new RateLimiter(),
} = {}) {
  const apiKeys = parseApiKeys(env.TRACK_BILLING_API_KEYS);
  if (apiKeys.length === 0) {
    throw new Error('TRACK_BILLING_API_KEYS must contain at least one non-empty key');
  }

  const rtdnSecret = env.TRACK_RTDN_SECRET;
  if (!rtdnSecret || String(rtdnSecret).trim().length === 0) {
    throw new Error('TRACK_RTDN_SECRET is required');
  }

  const storePath = env.TRACK_STORE_PATH;
  if (!storePath || String(storePath).trim().length === 0) {
    throw new Error('TRACK_STORE_PATH is required');
  }

  const billingStore = store || new BillingStore(storePath);
  const billingVerifier =
    verifier || new PlayPurchaseVerifier({ playClient: playClient || createPlayClientFromEnv(env) });

  const server = createBillingServer({
    verifier: billingVerifier,
    store: billingStore,
    apiKeys,
    rtdnSecret,
    rateLimiter,
    logger,
  });

  return { server, store: billingStore, verifier: billingVerifier, apiKeys, rtdnSecret };
}

async function main() {
  const logger = createLogger();
  const { server } = createService({ logger });
  const port = Number(process.env.PORT || 8080);

  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '0.0.0.0', resolve);
  });

  logger.log('service_started', { port, store: process.env.TRACK_STORE_PATH });

  let stopping = false;
  const shutdown = (signal) => {
    if (stopping) return;
    stopping = true;
    logger.log('service_stopping', { signal });
    server.close(() => process.exit(0));
    // Do not hang forever on a keep-alive socket.
    setTimeout(() => process.exit(0), 5000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

if (require.main === module) {
  main().catch((err) => {
    // The logger redacts secrets, but a startup failure is also written to
    // stderr so the platform captures it even if stdout is not collected.
    process.stderr.write(
      JSON.stringify({ event: 'service_failed', error: err && err.message ? err.message : String(err) }) + '\n',
    );
    process.exit(1);
  });
}

module.exports = { createService, main, parseApiKeys };
