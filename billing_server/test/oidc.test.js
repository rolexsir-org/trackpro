'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const { OidcVerifier } = require('../src/oidc');
const { createBillingServer } = require('../src/server');
const { BillingStore } = require('../src/store');
const { RateLimiter, createLogger } = require('../src/security');

const KID = 'test-kid';
const AUDIENCE = 'https://billing.example.com/rtdn';
const SA_EMAIL = 'service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com';
const FIXED_NOW = 1_700_000_000; // arbitrary fixed epoch (seconds)

function makeKeys() {
  return crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });
}

function signJwt(payload, privateKeyPem, { kid = KID, alg = 'RS256' } = {}) {
  const header = { alg, typ: 'JWT', kid };
  const h = Buffer.from(JSON.stringify(header)).toString('base64url');
  const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signingInput = `${h}.${p}`;
  const sig = crypto.sign('sha256', Buffer.from(signingInput, 'utf8'), crypto.createPrivateKey(privateKeyPem));
  return `${signingInput}.${sig.toString('base64url')}`;
}

function signJwtRaw(header, payload, privateKeyPem) {
  const h = Buffer.from(JSON.stringify(header)).toString('base64url');
  const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signingInput = `${h}.${p}`;
  const sig = crypto.sign('sha256', Buffer.from(signingInput, 'utf8'), crypto.createPrivateKey(privateKeyPem));
  return `${signingInput}.${sig.toString('base64url')}`;
}

function certsProviderFor(publicKeyPem) {
  return async (kid) => (kid === KID ? publicKeyPem : null);
}

function basePayload(overrides = {}) {
  return {
    iss: 'https://accounts.google.com',
    aud: AUDIENCE,
    exp: FIXED_NOW + 3600,
    iat: FIXED_NOW - 10,
    email: SA_EMAIL,
    email_verified: true,
    ...overrides,
  };
}

function newVerifier(keys, overrides = {}) {
  return new OidcVerifier({
    audience: AUDIENCE,
    expectedEmail: SA_EMAIL,
    certsProvider: certsProviderFor(keys.publicKey),
    now: () => FIXED_NOW,
    ...overrides,
  });
}

// ---------------------------------------------------------------------------
// Unit: OidcVerifier.verify
// ---------------------------------------------------------------------------

test('oidc.1: a valid Google-signed JWT (sig/iss/aud/exp/email) verifies', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(basePayload(), keys.privateKey);
  assert.equal(await v.verify(token), true);
});

test('oidc.2: token signed by an unknown key is rejected', async () => {
  const keys = makeKeys();
  const other = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(basePayload(), other.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.3: expired token (exp in the past) is rejected', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(basePayload({ exp: FIXED_NOW - 100 }), keys.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.4: wrong audience is rejected', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(basePayload({ aud: 'https://evil.example.com' }), keys.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.5: wrong issuer is rejected', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(basePayload({ iss: 'https://evil.com' }), keys.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.6: wrong service-account email is rejected when expectedEmail is set', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(
    basePayload({ email: 'service-999999999999@gcp-sa-pubsub.iam.gserviceaccount.com' }),
    keys.privateKey,
  );
  assert.equal(await v.verify(token), false);
});

test('oidc.7: a non-JWT bearer is rejected', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  assert.equal(await v.verify('not-a-jwt'), false);
  assert.equal(await v.verify('Bearer.only.two.parts?'), false);
});

test('oidc.8: missing kid is rejected', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwtRaw({ alg: 'RS256', typ: 'JWT' }, basePayload(), keys.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.9: non-RS256 algorithm is rejected before any crypto', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwtRaw({ alg: 'HS256', typ: 'JWT', kid: KID }, basePayload(), keys.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.10: both Google issuer forms are accepted', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const t1 = signJwt(basePayload({ iss: 'https://accounts.google.com' }), keys.privateKey);
  const t2 = signJwt(basePayload({ iss: 'accounts.google.com' }), keys.privateKey);
  assert.equal(await v.verify(t1), true);
  assert.equal(await v.verify(t2), true);
});

test('oidc.11: iat in the future is rejected', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const token = signJwt(basePayload({ iat: FIXED_NOW + 100 }), keys.privateKey);
  assert.equal(await v.verify(token), false);
});

test('oidc.12: email mismatch is ignored when expectedEmail is not configured', async () => {
  const keys = makeKeys();
  const v = new OidcVerifier({
    audience: AUDIENCE,
    certsProvider: certsProviderFor(keys.publicKey),
    now: () => FIXED_NOW,
  });
  const token = signJwt(
    basePayload({ email: 'service-999999999999@gcp-sa-pubsub.iam.gserviceaccount.com' }),
    keys.privateKey,
  );
  assert.equal(await v.verify(token), true);
});

// ---------------------------------------------------------------------------
// Integration: /rtdn authenticates via OIDC
// ---------------------------------------------------------------------------

function rtdnEnvelope(payload) {
  return { message: { data: Buffer.from(JSON.stringify(payload), 'utf8').toString('base64') } };
}

async function postRtdn(baseUrl, token, body) {
  return fetch(`${baseUrl}/rtdn`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

async function withOidcServer(oidcVerifier, rtdnSecret, fn) {
  const logs = [];
  const store = new BillingStore(null);
  const verifier = {
    async verify() {
      return {
        valid: true,
        expiresAt: '2030-01-01T00:00:00.000Z',
        autoRenew: true,
        inGracePeriod: false,
        trialEndsAt: null,
      };
    },
  };
  const srv = createBillingServer({
    verifier,
    store,
    apiKeys: ['k'],
    rtdnSecret: rtdnSecret ?? null,
    oidcVerifier,
    rateLimiter: new RateLimiter({ capacity: 50, refillPerSec: 10 }),
    logger: createLogger((l) => logs.push(l)),
    maxBodyBytes: 4096,
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const port = srv.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;
  try {
    await fn({ baseUrl, logs });
  } finally {
    await new Promise((r) => srv.close(r));
  }
}

test('oidc.13: /rtdn with a valid OIDC JWT returns 200', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  await withOidcServer(v, null, async ({ baseUrl }) => {
    const token = signJwt(basePayload(), keys.privateKey);
    const res = await postRtdn(baseUrl, token, rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.ok, true);
    assert.equal(body.action, 'test_notification');
  });
});

test('oidc.14: /rtdn with an expired OIDC JWT returns 401', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  await withOidcServer(v, null, async ({ baseUrl }) => {
    const token = signJwt(basePayload({ exp: FIXED_NOW - 100 }), keys.privateKey);
    const res = await postRtdn(baseUrl, token, rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(res.status, 401);
  });
});

test('oidc.15: /rtdn with a wrong-audience OIDC JWT returns 401', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  await withOidcServer(v, null, async ({ baseUrl }) => {
    const token = signJwt(basePayload({ aud: 'https://evil.example.com' }), keys.privateKey);
    const res = await postRtdn(baseUrl, token, rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(res.status, 401);
  });
});

test('oidc.16: /rtdn with a wrong-service-account OIDC JWT returns 401', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  await withOidcServer(v, null, async ({ baseUrl }) => {
    const token = signJwt(
      basePayload({ email: 'service-999999999999@gcp-sa-pubsub.iam.gserviceaccount.com' }),
      keys.privateKey,
    );
    const res = await postRtdn(baseUrl, token, rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(res.status, 401);
  });
});

test('oidc.17: OIDC and static secret coexist; missing auth is 401', async () => {
  const keys = makeKeys();
  const v = newVerifier(keys);
  const secret = 'shared_secret_xyz';
  await withOidcServer(v, secret, async ({ baseUrl }) => {
    // Static secret (not a JWT) still authenticates.
    const r1 = await postRtdn(baseUrl, secret, rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(r1.status, 200);
    // OIDC JWT also authenticates.
    const r2 = await postRtdn(baseUrl, signJwt(basePayload(), keys.privateKey), rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(r2.status, 200);
    // No auth -> 401.
    const r3 = await fetch(`${baseUrl}/rtdn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(rtdnEnvelope({ packageName: 'com.track.app', testNotification: true })),
    });
    assert.equal(r3.status, 401);
  });
});

test('oidc.18: a forged JWT is never downgraded to the shared secret', async () => {
  const keys = makeKeys();
  const other = makeKeys();
  const v = newVerifier(keys);
  await withOidcServer(v, 'shared_secret_xyz', async ({ baseUrl }) => {
    // Signed by an unknown key, but a static secret is configured.
    const forged = signJwt(basePayload(), other.privateKey);
    const res = await postRtdn(baseUrl, forged, rtdnEnvelope({ packageName: 'com.track.app', testNotification: true }));
    assert.equal(res.status, 401);
  });
});
