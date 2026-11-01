'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { createPlayClient, createPlayClientFromEnv } = require('../src/play_client');

const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});

const CREDENTIALS = {
  client_email: 'trackpro-billing@example.iam.gserviceaccount.com',
  private_key: privateKey,
  token_uri: 'https://oauth2.googleapis.com/token',
};

const NOW = 1_000_000_000_000;

function decodeBase64url(segment) {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
}

function makeTransport({ tokenResponse, apiResponse, apiError } = {}) {
  const calls = [];
  const request = async (url, options = {}) => {
    calls.push({ url, options });
    if (url === 'https://oauth2.googleapis.com/token') {
      return tokenResponse || { statusCode: 200, body: { access_token: 'at_1', expires_in: 3600 } };
    }
    if (apiError) throw apiError;
    return apiResponse || { statusCode: 200, body: { ok: true } };
  };
  return { calls, request };
}

test('play_client.1: signs a JWT, exchanges it, and calls subscriptionsv2 with the bearer token', async () => {
  const { calls, request } = makeTransport({
    apiResponse: {
      statusCode: 200,
      body: {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [
          {
            productId: 'track_pro_annual',
            expiryTime: '2027-10-18T12:00:00.000Z',
            autoRenewingPlan: { autoRenewEnabled: true },
          },
        ],
      },
    },
  });

  const client = createPlayClient({
    credentials: CREDENTIALS,
    now: () => NOW,
    request,
  });

  const result = await client.getSubscriptionV2({
    packageName: 'com.track.app',
    productId: 'track_pro_annual',
    purchaseToken: 'tok_123',
  });

  assert.equal(result.subscriptionState, 'SUBSCRIPTION_STATE_ACTIVE');
  assert.equal(calls.length, 2);

  const tokenCall = calls[0];
  assert.equal(tokenCall.url, 'https://oauth2.googleapis.com/token');
  assert.equal(tokenCall.options.method, 'POST');
  const form = new URLSearchParams(tokenCall.options.body);
  assert.equal(form.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer');
  const assertion = form.get('assertion');
  const [headerB64, payloadB64, signatureB64] = assertion.split('.');
  const header = decodeBase64url(headerB64);
  const payload = decodeBase64url(payloadB64);
  assert.equal(header.alg, 'RS256');
  assert.equal(payload.iss, CREDENTIALS.client_email);
  assert.equal(payload.scope, 'https://www.googleapis.com/auth/androidpublisher');
  assert.equal(payload.aud, 'https://oauth2.googleapis.com/token');
  assert.equal(payload.iat, Math.floor(NOW / 1000));
  assert.equal(payload.exp, payload.iat + 3600);

  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(`${headerB64}.${payloadB64}`);
  assert.equal(verifier.verify(publicKey, Buffer.from(signatureB64, 'base64url')), true);

  const apiCall = calls[1];
  assert.equal(
    apiCall.url,
    'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.track.app/purchases/subscriptionsv2/track_pro_annual/tokens/tok_123',
  );
  assert.equal(apiCall.options.headers.Authorization, 'Bearer at_1');
});

test('play_client.2: caches the access token across calls', async () => {
  const { calls, request } = makeTransport();
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => NOW, request });
  await client.getSubscriptionV2({ packageName: 'com.track.app', productId: 'track_pro_annual', purchaseToken: 'tok_123' });
  await client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' });
  assert.equal(calls.filter((c) => c.url === 'https://oauth2.googleapis.com/token').length, 1);
  assert.equal(calls.length, 3);
});

test('play_client.3: refreshes the token after expiry', async () => {
  let nowMs = NOW;
  const { calls, request } = makeTransport();
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => nowMs, request });
  await client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' });
  nowMs += 3_600_000;
  await client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' });
  assert.equal(calls.filter((c) => c.url === 'https://oauth2.googleapis.com/token').length, 2);
});

test('play_client.4: maps 404/410 to token_not_found and never includes the token in the message', async () => {
  const { request } = makeTransport({ apiResponse: { statusCode: 404, body: { error: 'not found' } } });
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => NOW, request });
  await assert.rejects(
    () => client.getSubscriptionV2({ packageName: 'com.track.app', productId: 'track_pro_annual', purchaseToken: 'tok_123' }),
    (err) => {
      assert.equal(err.code, 'token_not_found');
      assert.equal(err.statusCode, 404);
      assert.doesNotMatch(err.message, /tok_123/);
      return true;
    },
  );
});

test('play_client.5: maps 400 to invalid_token', async () => {
  const { request } = makeTransport({ apiResponse: { statusCode: 400, body: {} } });
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => NOW, request });
  await assert.rejects(
    () => client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' }),
    (err) => {
      assert.equal(err.code, 'invalid_token');
      assert.equal(err.statusCode, 400);
      return true;
    },
  );
});

test('play_client.6: maps 5xx to a retryable play_api_error', async () => {
  const { request } = makeTransport({ apiResponse: { statusCode: 503, body: {} } });
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => NOW, request });
  await assert.rejects(
    () => client.getSubscriptionV2({ packageName: 'com.track.app', productId: 'track_pro_annual', purchaseToken: 'tok_123' }),
    (err) => {
      assert.equal(err.code, 'play_api_error');
      assert.equal(err.statusCode, 503);
      return true;
    },
  );
});

test('play_client.7: a network failure is play_unreachable, not a rejection', async () => {
  const { request } = makeTransport({
    apiError: Object.assign(new Error('socket hang up'), { code: 'ECONNRESET' }),
  });
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => NOW, request });
  await assert.rejects(
    () => client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' }),
    (err) => {
      assert.equal(err.code, 'play_unreachable');
      return true;
    },
  );
});

test('play_client.8: a failed token exchange is play_unreachable', async () => {
  const { request } = makeTransport({ tokenResponse: { statusCode: 401, body: {} } });
  const client = createPlayClient({ credentials: CREDENTIALS, now: () => NOW, request });
  await assert.rejects(
    () => client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' }),
    (err) => {
      assert.equal(err.code, 'play_unreachable');
      assert.equal(err.statusCode, 401);
      return true;
    },
  );
});

test('play_client.9: createPlayClientFromEnv reads an inline JSON key', async () => {
  const { request } = makeTransport();
  const client = createPlayClientFromEnv(
    { GOOGLE_APPLICATION_CREDENTIALS_JSON: JSON.stringify(CREDENTIALS) },
    { now: () => NOW, request },
  );
  const result = await client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' });
  assert.deepEqual(result, { ok: true });
});

test('play_client.10: createPlayClientFromEnv reads a file path and unescapes newlines', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'trackpro-play-'));
  const file = path.join(dir, 'service-account.json');
  const escaped = { ...CREDENTIALS, private_key: privateKey.replace(/\n/g, '\\n') };
  fs.writeFileSync(file, JSON.stringify(escaped), 'utf8');
  try {
    const { request } = makeTransport();
    const client = createPlayClientFromEnv(
      { GOOGLE_APPLICATION_CREDENTIALS: file },
      { now: () => NOW, request },
    );
    const result = await client.getProduct({ packageName: 'com.track.app', productId: 'track_pro_lifetime', purchaseToken: 'tok_456' });
    assert.deepEqual(result, { ok: true });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('play_client.11: missing credentials fail with a clear error', () => {
  assert.throws(() => createPlayClientFromEnv({}), /GOOGLE_APPLICATION_CREDENTIALS/);
  assert.throws(() => createPlayClient({ credentials: {} }), /client_email/);
});
