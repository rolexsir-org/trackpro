import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:track/config/pro_config.dart';
import 'package:track/services/billing_service.dart';
import 'package:track/services/pro_analytics.dart';

/// Monetisation acceptance tests.
///
/// These are the rules the business model actually depends on, written as tests
/// so a future refactor cannot quietly hand out Pro or lock away data someone
/// already logged. Everything here runs without Play Billing, without a
/// database and without a device: the policy is pure.
void main() {
  // The verifier suite needs a loopback socket. If the environment forbids one it
  // is reported as skipped rather than allowed to pass unnoticed.
  try {
    final probe = HttpServer.bindSync(InternetAddress.loopbackIPv4, 0);
    probe.close();
    mainHttpVerifierTests();
  } on Object catch (error) {
    test('HttpPurchaseVerifier suite', () {}, skip: 'no loopback socket in this environment: $error');
  }

  group('entitlement — no purchase means no Pro', () {
    test('the default entitlement is free', () {
      expect(Entitlement.free.isPro, isFalse);
      expect(Entitlement.free.active, isFalse);
      expect(Entitlement.free.planTitle, 'Track Pro');
    });

    test('a server-verified purchase grants Pro', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_annual',
        productId: 'track_pro_annual',
        expiresAt: DateTime.now().add(const Duration(days: 300)),
        autoRenew: true,
        purchaseToken: 'tok_annual',
        source: 'play',
        verified: true,
        verifiedAt: DateTime.now(),
      );
      expect(ent.active, isTrue);
      expect(ent.isLifetime, isFalse);
      expect(ent.planTitle, 'Track Pro Annual');
      expect(ent.statusLine, contains('Annual'));
    });

    // The decision reversed here was "grant first, verify later". It handed Pro to
    // anyone who could make the client believe a purchase happened (a patched APK,
    // a replayed token) and it kept granting after refunds. Entitlement is now
    // fail-closed: a claim that the backend has not confirmed is worth nothing.
    test('an unverified purchase grants nothing, and says why', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_monthly',
        productId: 'track_pro_monthly',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        purchaseToken: 'tok_monthly',
        source: 'play',
        verified: false,
      );
      expect(ent.active, isFalse);
      expect(ent.inactiveReason, isNotNull);
    });

    test('a recognised product id is not itself a grant', () {
      // The regression this guards: `ProConfig.planForProduct(id) != null` used to
      // be sufficient to unlock Pro.
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_lifetime',
        productId: 'track_pro_lifetime',
        source: 'play',
      );
      expect(ProConfig.planForProduct('track_pro_lifetime'), isNotNull, reason: 'the id is known');
      expect(ent.active, isFalse, reason: 'but knowing the id is not paying for it');
    });

    test('a verification older than the staleness window stops counting', () {
      final stale = Entitlement(
        isPro: true,
        planId: 'track_pro_annual',
        productId: 'track_pro_annual',
        expiresAt: DateTime.now().add(const Duration(days: 300)),
        autoRenew: true,
        source: 'server',
        verified: true,
        verifiedAt: DateTime.now().subtract(const Duration(days: 8)),
      );
      expect(stale.active, isFalse, reason: 'a week offline is the ceiling, not a new baseline');
      expect(stale.inactiveReason, isNotNull);

      final fresh = Entitlement(
        isPro: true,
        planId: 'track_pro_annual',
        productId: 'track_pro_annual',
        expiresAt: DateTime.now().add(const Duration(days: 300)),
        autoRenew: true,
        source: 'server',
        verified: true,
        verifiedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(fresh.active, isTrue, reason: 'a couple of days offline keeps working');
    });

    test('a subscription that reports no expiry is not active', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_monthly',
        productId: 'track_pro_monthly',
        source: 'server',
        verified: true,
        verifiedAt: DateTime.now(),
      );
      expect(ent.active, isFalse, reason: 'an open-ended subscription is exactly what a forged claim looks like');
    });
  });

  group('entitlement — pending purchases grant nothing', () {
    test('a pending subscription is not active', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_monthly',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        source: 'play',
        pending: true,
      );
      expect(ent.active, isFalse);
    });

    test('a cancelled purchase (isPro: false) is not active', () {
      const ent = Entitlement(isPro: false, planId: 'track_pro_monthly', source: 'play');
      expect(ent.active, isFalse);
    });
  });

  group('entitlement — lifetime never expires', () {
    test('a lifetime purchase with no expiry stays active', () {
      const ent = Entitlement(
        isPro: true,
        planId: 'track_pro_lifetime',
        productId: 'track_pro_lifetime',
        purchaseToken: 'tok_life',
        source: 'play',
        verified: true,
      );
      expect(ent.isLifetime, isTrue);
      expect(ent.active, isTrue);
      expect(ent.planTitle, 'Track Pro Lifetime');
      expect(ent.statusLine, contains('Lifetime'));
    });

    test('autorenew is irrelevant for lifetime', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_lifetime',
        autoRenew: false,
        expiresAt: DateTime.now().subtract(const Duration(days: 9000)),
        source: 'play',
        // `verified: true` is not decoration. Every "expect(active, isTrue)" in this
        // file has to satisfy the fail-closed rule the group above pins — an
        // entitlement the server has not confirmed is worth nothing — and this test
        // was written before that rule landed, so it asserted a grant from a
        // client-side claim alone. Exactly the thing that must never come back.
        verified: true,
      );
      // A lifetime grant ignores whatever expiry was cached alongside it.
      expect(ent.isLifetime, isTrue);
      expect(ent.active, isTrue);
    });
  });

  group('entitlement — expiry and the offline grace window', () {
    // All three cases below now carry `verified: true` plus a fresh `verifiedAt`.
    // Without them the entitlement is inactive for a *different* reason (no server
    // confirmation, or a stale check), the "inside the grace window" case failed, and
    // the two `isFalse` cases passed for the wrong reason — a test that cannot tell
    // which rule fired is not pinning the rule it names.
    Entitlement subscription({required DateTime expiresAt}) => Entitlement(
          isPro: true,
          planId: 'track_pro_annual',
          expiresAt: expiresAt,
          source: 'cache',
          verified: true,
          verifiedAt: DateTime.now(),
        );

    test('a subscription inside the grace window is still active', () {
      expect(subscription(expiresAt: DateTime.now().subtract(const Duration(hours: 6))).active, isTrue);
    });

    test('a subscription past expiry + grace is not active', () {
      final ent = subscription(
        expiresAt: DateTime.now().subtract(Entitlement.offlineGrace).subtract(const Duration(hours: 1)),
      );
      expect(ent.active, isFalse);
    });

    test('the grace window is bounded at 3 days', () {
      expect(Entitlement.offlineGrace, const Duration(days: 3));
      // One minute either side of the same boundary, so the constant is what is
      // being tested and not the sample.
      final justInside = subscription(
        expiresAt: DateTime.now().subtract(const Duration(days: 2, hours: 23, minutes: 59)),
      );
      final justOutside = subscription(expiresAt: DateTime.now().subtract(const Duration(days: 3, minutes: 1)));
      expect(justInside.active, isTrue);
      expect(justOutside.active, isFalse);
    });
  });

  group('entitlement — trial state', () {
    test('a running trial reports days left', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_annual',
        expiresAt: DateTime.now().add(const Duration(days: 365)),
        trialEndsAt: DateTime.now().add(const Duration(days: 5)),
        autoRenew: true,
        purchaseToken: 'tok_trial',
        source: 'play',
      );
      expect(ent.inTrial, isTrue);
      expect(ent.trialDaysLeft, inInclusiveRange(4, 5));
      expect(ent.planTitle, 'Track Pro trial');
      expect(ent.statusLine.contains('left'), isTrue);
    });

    test('an ended trial is no longer a trial', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_annual',
        expiresAt: DateTime.now().add(const Duration(days: 360)),
        trialEndsAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'play',
      );
      expect(ent.inTrial, isFalse);
      expect(ent.trialDaysLeft, 0);
      expect(ent.active, isTrue); // the paid year continues
    });
  });

  group('entitlement — persistence round-trip', () {
    test('toJson/fromJson survives a cold start', () {
      final ent = Entitlement(
        isPro: true,
        planId: 'track_pro_annual',
        productId: 'track_pro_annual',
        expiresAt: DateTime.utc(2027, 1, 14, 9, 12),
        trialEndsAt: DateTime.utc(2026, 10, 22, 9, 12),
        autoRenew: true,
        purchaseToken: 'tok_persist',
        source: 'play',
        verified: true,
        inGracePeriod: false,
      );
      final restored = Entitlement.fromJson(ent.toJson());
      expect(restored.isPro, isTrue);
      expect(restored.planId, 'track_pro_annual');
      expect(restored.purchaseToken, 'tok_persist');
      expect(restored.expiresAt, ent.expiresAt);
      expect(restored.autoRenew, isTrue);
      expect(restored.verified, isTrue);
      expect(restored.active, isTrue);
    });

    test('a cache that says free stays free after a restart', () {
      final restored = Entitlement.fromJson(const {'isPro': false, 'source': 'cache'});
      expect(restored.isPro, isFalse);
      expect(restored.active, isFalse);
    });

    test('a partially written cache still round-trips without throwing', () {
      // AppState wraps this in a try/catch and degrades to free on any throw, so
      // the only hard requirement is that a sparse map never blows up.
      final restored = Entitlement.fromJson(const {'planId': 'track_pro_annual'});
      expect(restored.isPro, isFalse);
      expect(restored.active, isFalse);
    });
  });

  group('a provisional claim is bookkeeping, never access', () {
    // This group used to assert that a locally-recognised purchase was good for a
    // year without asking anyone. It is now the opposite: the token is remembered
    // so it can be retried, and it unlocks nothing until the server says so.
    test('a provisional annual claim is pending and inactive', () {
      final ent = Entitlement.provisional(
        productId: 'track_pro_annual',
        purchaseToken: 'tok_prov',
        purchasedAt: DateTime.now(),
        trial: true,
      );
      expect(ent.active, isFalse);
      expect(ent.pending, isTrue);
      expect(ent.verified, isFalse);
      expect(ent.purchaseToken, 'tok_prov', reason: 'the token is kept so verification can be retried');
    });

    test('an unknown product id grants nothing and is not even queued', () {
      final ent = Entitlement.provisional(
        productId: 'someone_elses_sku',
        purchaseToken: 'tok_unknown',
        purchasedAt: DateTime.now(),
      );
      expect(ent.active, isFalse);
      expect(ent.isPro, isFalse);
    });
  });

  group('verification verdicts', () {
    test('only a valid verdict carries an expiry', () {
      final valid = VerifyResult(
        valid: true,
        expiresAt: DateTime.now().add(const Duration(days: 300)),
        autoRenew: true,
      );
      expect(valid.valid, isTrue);
      expect(valid.reachable, isTrue);
      expect(valid.pending, isFalse);
      expect(valid.expiresAt, isNotNull);
    });

    test('an outage is not a rejection', () {
      expect(VerifyResult.unreachable.reachable, isFalse);
      expect(VerifyResult.unreachable.valid, isFalse);
      expect(VerifyResult.unreachable.pending, isFalse);
    });

    test('a rejection is not an outage', () {
      final rejected = VerifyResult.rejected('token_not_found');
      expect(rejected.reachable, isTrue, reason: 'we asked and were answered');
      expect(rejected.valid, isFalse);
      expect(rejected.reason, 'token_not_found');
    });

    test('a pending purchase is neither valid nor a rejection', () {
      final pending = VerifyResult.pendingPurchase();
      expect(pending.pending, isTrue);
      expect(pending.valid, isFalse);
      expect(pending.reachable, isTrue);
    });

    test('the default verdict is invalid', () {
      expect(VerifyResult.invalid.valid, isFalse);
      expect(VerifyResult.invalid.reachable, isTrue);
    });
  });

  group('free limits — tracker ceiling', () {
    test('free stops at 3 trackers', () {
      expect(ProConfig.freeTrackerLimit, 3);
      expect(ProConfig.canAddTracker(isPro: false, active: 0), isTrue);
      expect(ProConfig.canAddTracker(isPro: false, active: 2), isTrue);
      expect(ProConfig.canAddTracker(isPro: false, active: 3), isFalse);
      expect(ProConfig.canAddTracker(isPro: false, active: 9), isFalse);
    });

    test('Pro has no ceiling', () {
      expect(ProConfig.canAddTracker(isPro: true, active: 3), isTrue);
      expect(ProConfig.canAddTracker(isPro: true, active: 40), isTrue);
    });
  });

  group('free limits — history window', () {
    test('free sees 7 days', () {
      expect(ProConfig.freeHistoryDays, 7);
      expect(ProConfig.historyWindowDays(isPro: false, available: 90), 7);
    });

    test('free never claims more history than it has', () {
      // A user on day 3 sees 3 days, not a 7-day chart padded with zeros.
      expect(ProConfig.historyWindowDays(isPro: false, available: 3), 3);
    });

    test('Pro sees everything the repository holds', () {
      expect(ProConfig.historyWindowDays(isPro: true, available: 90), 90);
    });

    test('the lock marker starts exactly one day past the free window', () {
      expect(ProConfig.isHistoryLocked(isPro: false, daysAgo: 6), isFalse);
      expect(ProConfig.isHistoryLocked(isPro: false, daysAgo: 7), isTrue);
      expect(ProConfig.isHistoryLocked(isPro: true, daysAgo: 365), isFalse);
    });
  });

  group('free limits — widget rings', () {
    test('one ring free, three with Pro', () {
      expect(ProConfig.widgetRings(isPro: false), 1);
      expect(ProConfig.widgetRings(isPro: true), 3);
    });
  });

  group('catalogue — the Play Console contract', () {
    test('the product ids are exactly the ones created in Play Console', () {
      // `ProPlan.id` *is* the Play product id — there is no separate `productId`
      // field, and this line used to name one, which failed to compile the whole
      // suite (`flutter test` could not build a single test file because of it).
      final ids = ProConfig.plans.map((p) => p.id).toList();
      expect(ids, containsAll(<String>['track_pro_monthly', 'track_pro_annual', 'track_pro_lifetime']));
    });

    test('the base plan and offer ids match MONETIZATION.md', () {
      expect(ProConfig.monthlyBasePlanId, 'monthly-auto');
      expect(ProConfig.annualBasePlanId, 'annual-auto');
      expect(ProConfig.trialOfferId, 'free-trial-7d');
    });

    test('exactly one plan is highlighted — the annual', () {
      final highlighted = ProConfig.plans.where((p) => p.highlighted).toList();
      expect(highlighted, hasLength(1));
      expect(highlighted.single.id, 'track_pro_annual');
      expect(ProConfig.highlighted.id, 'track_pro_annual');
    });

    test('only subscriptions carry a trial, and it is 7 days', () {
      expect(ProConfig.trialDays, 7);
      for (final p in ProConfig.plans) {
        if (p.kind == PlanKind.lifetime) {
          expect(p.hasTrial, isFalse);
          expect(p.trialDays, 0);
        } else {
          expect(p.subscription, isTrue);
        }
      }
      expect(ProConfig.plans.firstWhere((p) => p.id == 'track_pro_annual').hasTrial, isTrue);
    });

    test('fallback prices render when Play is unreachable', () {
      for (final p in ProConfig.plans) {
        expect(p.price, isNull);
        expect(p.displayPrice, p.fallbackPrice);
        expect(p.displayPrice, isNotEmpty);
        expect(p.displayPeriod, isNotEmpty);
      }
      expect(ProConfig.fallbackMonthly, '₹399');
      expect(ProConfig.fallbackAnnual, '₹2,499');
      expect(ProConfig.fallbackLifetime, '₹4,999');
    });

    test('a Play price always beats the fallback', () {
      final annual = ProConfig.plans.firstWhere((p) => p.id == 'track_pro_annual');
      final priced = annual.copyWith(
        price: '\$34.99',
        rawPrice: 34.99,
        currencySymbol: '\$',
        currencyCode: 'USD',
      );
      // Play's localized, per-cohort price is the only one we ever show.
      expect(priced.displayPrice, '\$34.99');
      // `displayPeriod` is appended with no separator ('$displayPrice$displayPeriod'
      // in ctaFor), so it is the compact '/year' form — 'per year' rendered as
      // "$34.99per year". The assertion was stale, the implementation is right.
      expect(priced.displayPeriod, '/year');
      // …and an unpriced plan falls back without ever rendering an empty string.
      expect(annual.displayPrice, ProConfig.fallbackAnnual);
      expect(annual.displayPeriod, '/year');
    });

    test('lifetime is a one-time purchase and says so', () {
      final life = ProConfig.plans.firstWhere((p) => p.kind == PlanKind.lifetime);
      expect(life.subscription, isFalse);
      expect(life.ctaFor(), isNot(contains('trial')));
      expect(life.trialTimeline().toLowerCase(), isNot(contains('free')));
    });

    test('the annual CTA states the trial, and the trial timeline is concrete', () {
      final annual = ProConfig.highlighted;
      expect(annual.ctaFor().toLowerCase(), contains('free'));
      final timeline = annual.trialTimeline();
      expect(timeline, contains('7'));
      expect(timeline.toLowerCase(), contains('cancel'));
    });

    test('an unknown product id resolves to no plan', () {
      expect(ProConfig.planForProduct('track_pro_forever'), isNull);
    });
  });

  group('paywall placements', () {
    test('every trigger has a title and a body', () {
      for (final t in PaywallTrigger.values) {
        expect(t.title, isNotEmpty, reason: '$t needs a title');
        expect(t.body, isNotEmpty, reason: '$t needs a body');
        expect(t.key, isNotEmpty);
      }
    });

    test('gate keys map to the placement that should open', () {
      expect(ProConfig.triggerFor('tracker_limit'), PaywallTrigger.trackerLimit);
      expect(ProConfig.triggerFor('history'), PaywallTrigger.historyLock);
      expect(ProConfig.triggerFor('insights'), PaywallTrigger.insightsLock);
      expect(ProConfig.triggerFor('health'), PaywallTrigger.healthSync);
      expect(ProConfig.triggerFor('streak'), PaywallTrigger.streakSave);
      expect(ProConfig.triggerFor('nonsense'), isNull);
    });

    test('paywall copy never promises a feature the free tier already has', () {
      // "Export is free" is the trust line that keeps the paywall honest; it must
      // never appear as a paid benefit.
      final benefitText = ProConfig.benefits.map((b) => '${b.title} ${b.body}'.toLowerCase()).join(' ');
      expect(benefitText, isNot(contains('export')));
      expect(ProConfig.trustLines.join(' ').toLowerCase(), contains('export'));
    });
  });

  group('funnel analytics', () {
    test('the whitelist covers the whole purchase journey', () {
      for (final e in const [
        'paywall_viewed',
        'plan_selected',
        'purchase_started',
        'purchase_completed',
        'purchase_canceled',
        'purchase_error',
        'restore_completed',
        'pro_gate_tapped',
        'soft_prompt_shown',
      ]) {
        expect(ProAnalytics.funnel.contains(e), isTrue, reason: '$e must be tracked');
      }
    });

    test('unknown events are not funnel events', () {
      expect(ProAnalytics.funnel.contains('page_view'), isFalse);
      expect(ProAnalytics.funnel.contains(''), isFalse);
    });

    test('event metadata decodes to a map, and bad input to an empty one', () {
      expect(decodeEventMeta('{"trigger":"trackerLimit"}'), {'trigger': 'trackerLimit'});
      expect(decodeEventMeta(null), isEmpty);
      expect(decodeEventMeta('not json'), isEmpty);
      expect(decodeEventMeta('[1,2,3]'), isEmpty);
    });
  });
}

/// The HTTP verifier against a real socket.
///
/// The server is a `dart:io` `HttpServer` on the loopback interface, so the test
/// exercises the actual request, headers, status handling and JSON parsing — the
/// code that decides whether a purchase becomes Pro — rather than a mock of it.
/// If the environment cannot open a socket the group is skipped loudly, never
/// silently passed.
void mainHttpVerifierTests() {
  group('HttpPurchaseVerifier — the client contract with /billing/verify', () {
    late HttpServer server;
    late Uri endpoint;
    late List<HttpRequest> seen;
    late List<String> bodies;
    late Future<void> Function(HttpRequest request) respond;

    setUp(() async {
      seen = [];
      bodies = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint = Uri.parse('http://127.0.0.1:${server.port}/billing/verify');
      server.listen((request) async {
        seen.add(request);
        bodies.add(await utf8.decodeStream(request));
        await respond(request);
      });
      respond = (request) async {
        request.response.statusCode = 200;
        request.response.write('{"valid":false,"reason":"rejected"}');
        await request.response.close();
      };
    });

    tearDown(() async => server.close(force: true));

    HttpPurchaseVerifier verifier({Future<String?> Function()? bearer}) => HttpPurchaseVerifier(
          endpoint: endpoint,
          bearerTokenProvider: bearer,
          timeout: const Duration(seconds: 5),
        );

    test('a valid response is accepted with its expiry', () async {
      final expiry = DateTime.now().add(const Duration(days: 300)).toUtc().toIso8601String();
      respond = (request) async {
        request.response.write(jsonEncode({
          'valid': true,
          'expiresAt': expiry,
          'autoRenew': true,
          'inGracePeriod': false,
        }));
        await request.response.close();
      };

      final result = await verifier().verify(
        productId: 'track_pro_annual',
        purchaseToken: 'tok_valid',
        packageName: 'com.track.app',
      );

      expect(result.valid, isTrue);
      expect(result.expiresAt!.toUtc().difference(DateTime.parse(expiry)).inSeconds.abs(), lessThan(2));
      expect(result.autoRenew, isTrue);
    });

    test('the request carries the product, token and package', () async {
      await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok_roundtrip',
        packageName: 'com.track.app',
      );
      final sent = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect(sent['productId'], 'track_pro_monthly');
      expect(sent['purchaseToken'], 'tok_roundtrip');
      expect(sent['packageName'], 'com.track.app');
    });

    test('a bearer token is attached when the build provides one', () async {
      await verifier(bearer: () async => 'integrity-token-123').verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(seen.single.headers.value(HttpHeaders.authorizationHeader), 'Bearer integrity-token-123');
    });

    test('no Authorization header is sent when there is no token to send', () async {
      await verifier().verify(productId: 'track_pro_monthly', purchaseToken: 'tok', packageName: 'com.track.app');
      expect(seen.single.headers.value(HttpHeaders.authorizationHeader), isNull);
    });

    test('a pending purchase is reported as pending, not as rejected', () async {
      respond = (request) async {
        request.response.write('{"valid":false,"pending":true}');
        await request.response.close();
      };
      final result = await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok_pending',
        packageName: 'com.track.app',
      );
      expect(result.pending, isTrue);
      expect(result.reachable, isTrue);
      expect(result.valid, isFalse);
    });

    test('a rejection keeps its reason', () async {
      respond = (request) async {
        request.response.write('{"valid":false,"reason":"token_not_found"}');
        await request.response.close();
      };
      final result = await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok_forged',
        packageName: 'com.track.app',
      );
      expect(result.valid, isFalse);
      expect(result.reachable, isTrue, reason: 'we got an answer');
      expect(result.reason, 'token_not_found');
    });

    test('503 is an outage, so the caller retries instead of revoking', () async {
      respond = (request) async {
        request.response.statusCode = 503;
        request.response.write('{"valid":false,"retryable":true}');
        await request.response.close();
      };
      final result = await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(result.reachable, isFalse);
      expect(result.valid, isFalse);
    });

    test('429 is an outage too, not a refund', () async {
      respond = (request) async {
        request.response.statusCode = 429;
        await request.response.close();
      };
      final result = await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(result.reachable, isFalse);
    });

    test('401 is a rejection of this build, not of the purchase', () async {
      respond = (request) async {
        request.response.statusCode = 401;
        await request.response.close();
      };
      final result = await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(result.valid, isFalse);
      expect(result.reason, 'http_401');
    });

    test('malformed JSON never becomes a grant', () async {
      respond = (request) async {
        request.response.write('{not json at all');
        await request.response.close();
      };
      final result = await verifier().verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(result.valid, isFalse);
      expect(result.reachable, isFalse);
    });

    test('a timeout is an outage', () async {
      respond = (request) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        request.response.write('{"valid":true}');
        await request.response.close();
      };
      final verifierUnderTest = HttpPurchaseVerifier(
        endpoint: endpoint,
        timeout: const Duration(milliseconds: 400),
      );
      final result = await verifierUnderTest.verify(
        productId: 'track_pro_monthly',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(result.valid, isFalse);
      expect(result.reachable, isFalse);
    });

    test('an unconfigured build cannot grant Pro', () async {
      final result = await HttpPurchaseVerifier(endpoint: null).verify(
        productId: 'track_pro_annual',
        purchaseToken: 'tok',
        packageName: 'com.track.app',
      );
      expect(result.valid, isFalse);
      expect(result.reachable, isFalse);
      expect(seen, isEmpty, reason: 'nothing was called');
    });

    test('a purchase token is never echoed into the request line or headers', () async {
      await verifier(bearer: () async => 'integrity-token-123').verify(
        productId: 'track_pro_annual',
        purchaseToken: 'super-secret-token-value',
        packageName: 'com.track.app',
      );
      final request = seen.single;
      expect(request.uri.toString(), isNot(contains('super-secret-token-value')));
      final headerDump = request.headers.toString();
      expect(headerDump, isNot(contains('super-secret-token-value')));
    });
  });
}
