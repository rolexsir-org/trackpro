import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import '../config/pro_config.dart';
import 'pro_analytics.dart';

/// Google Play Billing, wrapped in one place.
///
/// Responsibilities kept here (and out of the UI):
/// 1. **Product queries** — Play returns one `GooglePlayProductDetails` *per
///    offer*, so we collapse them back into one `ProPlan` per product and keep
///    the offer token we need to launch the flow.
/// 2. **Purchases** — subscriptions go through `GooglePlayPurchaseParam` with an
///    `offerToken` (required for base plans and for the free-trial offer);
///    the lifetime product goes through the plain `PurchaseParam`.
/// 3. **Acknowledgement** — Play auto-refunds anything not acknowledged within
///    3 days. We acknowledge on every `purchased`/`restored` event, always.
/// 4. **Verification** — the purchase token is sent to our backend, which calls
///    the Play Developer API (`purchases.subscriptionsv2.get`). Entitlement is
///    granted optimistically and marked `verified: false` until that succeeds,
///    so a flaky network never blocks a paying user.
/// 5. **Lifecycle** — upgrades/downgrades via `ReplacementMode`, and "manage
///    subscription" deep-links into the Play subscription centre.
class BillingService extends ChangeNotifier {
  BillingService({
    ProAnalytics? analytics,
    PurchaseVerifier? verifier,
    this.packageName = 'com.track.app',
    this.environmentLabel = 'production',
  }) : _analytics = analytics,
       // No default verifier: an unconfigured billing service cannot grant Pro.
       // That is intentional — the previous default (a local stub that trusted
       // product ids) is exactly the bug this replaces. Dev builds inject
       // `LocalOnlyVerifier` explicitly, and it throws in release.
       _verifier = verifier;

  final ProAnalytics? _analytics;
  final PurchaseVerifier? _verifier;

  /// Sent to the verifier: a token received for another package is not ours.
  final String packageName;
  final String environmentLabel;

  /// Purchases Play has accepted but the server has not confirmed yet, keyed by
  /// purchase token. These grant nothing; the UI shows "confirming…".
  final Map<String, Entitlement> _awaitingVerification = <String, Entitlement>{};
  Map<String, Entitlement> get awaitingVerification => Map.unmodifiable(_awaitingVerification);

  /// True when a purchase is waiting on the backend — the paywall and Settings
  /// use this to show an honest state instead of a spinner that never ends.
  bool get hasPendingVerification => _awaitingVerification.isNotEmpty;

  /// The most recent server verdict, for diagnostics and support.
  String? lastVerifyOutcome;

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool available = false;
  bool loading = false;
  String? lastError;

  /// Store-enriched catalogue: prices, offer tokens, trial availability.
  List<ProPlan> plans = List<ProPlan>.from(ProConfig.plans);

  /// Purchases still being finalised (pending payment methods, verification).
  final Map<String, PurchaseDetails> _inFlight = <String, PurchaseDetails>{};

  Entitlement _entitlement = Entitlement.free;
  Entitlement get entitlement => _entitlement;

  /// Fires whenever the entitlement changes, so `AppState` can persist it.
  final StreamController<Entitlement> _updates = StreamController<Entitlement>.broadcast();
  Stream<Entitlement> get updates => _updates.stream;

  ProPlan? get currentPlan => _entitlement.planId == null ? null : ProConfig.planForProduct(_entitlement.planId!);

  // ------------------------------------------------------------------ start-up
  Future<void> init({Entitlement? cached}) async {
    // Cache the claim so its purchase token survives for re-verification. Note
    // that a cached entitlement with `verified: true` still has to be fresh — see
    // `Entitlement.active` — so this cannot become a permanent local grant.
    if (cached != null && cached.isPro) _apply(cached, persistNow: false);

    available = await _iap.isAvailable();
    if (!available) {
      // Sideloaded build, no Play Services, or a non-Play country: the app runs
      // fine, the paywall explains why it cannot sell anything here yet.
      lastError = 'Google Play Billing is not available on this device.';
      notifyListeners();
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        lastError = '$e';
        notifyListeners();
      },
    );

    await loadPlans();
    await restore();
  }

  Future<void> loadPlans() async {
    loading = true;
    notifyListeners();
    try {
      final ids = ProConfig.plans.map((p) => p.id).toSet();
      final response = await _iap.queryProductDetails(ids);
      if (response.notFoundIDs.isNotEmpty) {
        // Usually a Play Console configuration issue (base plan not active, or a
        // build signed with a different key). Surfaced, not swallowed.
        lastError = 'Not configured in Play Console: ${response.notFoundIDs.join(', ')}';
      }
      plans = _merge(response.productDetails);
    } catch (e) {
      lastError = '$e';
      plans = List<ProPlan>.from(ProConfig.plans);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Collapses Play's per-offer product details back into one plan per product.
  List<ProPlan> _merge(List<ProductDetails> found) {
    final byId = <String, ProPlan>{for (final p in ProConfig.plans) p.id: p};

    for (final details in found) {
      final base = byId[details.id];
      if (base == null) continue;

      if (!base.subscription) {
        // One-time product (lifetime): price sits on the details themselves.
        byId[details.id] = base.copyWith(
          price: details.price,
          rawPrice: details.rawPrice,
          currencyCode: details.currencyCode,
          currencySymbol: details.currencySymbol,
        );
        continue;
      }

      if (details is! GooglePlayProductDetails) {
        byId[details.id] = base.copyWith(
          price: details.price,
          rawPrice: details.rawPrice,
          currencySymbol: details.currencySymbol,
        );
        continue;
      }

      // Subscriptions: pick the offer we want to sell. Preference order:
      //   1. the free-trial offer (it is the conversion driver),
      //   2. the plain base plan,
      //   3. whatever Play returned first.
      final wrapper = details.productDetails;
      final offers = wrapper.subscriptionOfferDetails ?? const <SubscriptionOfferDetailsWrapper>[];
      if (offers.isEmpty) continue;

      SubscriptionOfferDetailsWrapper? chosen;
      for (final o in offers) {
        if (o.offerId == ProConfig.trialOfferId) {
          chosen = o;
          break;
        }
      }
      chosen ??= offers.firstWhere((o) => o.offerId == null, orElse: () => offers.first);

      final phase = chosen.pricingPhases.isNotEmpty ? chosen.pricingPhases.first : null;
      if (phase == null) continue;

      byId[details.id] = base.copyWith(
        price: _paidPhasePrice(chosen),
        rawPrice: _paidPhaseRawPrice(chosen),
        currencyCode: phase.priceCurrencyCode,
        currencySymbol: _symbolOf(chosen, details),
        offerId: chosen.offerId,
        offerToken: chosen.offerIdToken,
        basePlanId: chosen.basePlanId,
      );
    }

    return ProConfig.plans.map((p) => byId[p.id]!).toList();
  }

  /// The price the user will actually be charged — i.e. the first *paid* phase,
  /// skipping a ₹0 free-trial phase.
  String _paidPhasePrice(SubscriptionOfferDetailsWrapper offer) {
    for (final phase in offer.pricingPhases) {
      if (phase.priceAmountMicros > 0) return phase.formattedPrice;
    }
    return offer.pricingPhases.first.formattedPrice;
  }

  double? _paidPhaseRawPrice(SubscriptionOfferDetailsWrapper offer) {
    for (final phase in offer.pricingPhases) {
      if (phase.priceAmountMicros > 0) return phase.priceAmountMicros / 1000000.0;
    }
    return null;
  }

  String? _symbolOf(SubscriptionOfferDetailsWrapper offer, ProductDetails fallback) {
    final price = _paidPhasePrice(offer);
    final match = RegExp(r'^([^\d\s]+)').firstMatch(price);
    return match?.group(1) ?? fallback.currencySymbol;
  }

  // ------------------------------------------------------------------ purchase
  Future<bool> buy(ProPlan plan) async {
    if (!available) {
      lastError = 'Billing unavailable';
      notifyListeners();
      return false;
    }
    _analytics?.log('purchase_started', {'plan': plan.id, 'trigger': environmentLabel});

    final details = await _detailsFor(plan);
    if (details == null) {
      lastError = 'This plan is not available right now.';
      _analytics?.log('purchase_error', {'plan': plan.id, 'reason': 'product_not_found'});
      notifyListeners();
      return false;
    }

    final PurchaseParam param;
    if (plan.subscription) {
      // offerToken is mandatory for base plans; omit it and Play rejects the flow.
      param = GooglePlayPurchaseParam(productDetails: details, offerToken: plan.offerToken);
    } else {
      param = PurchaseParam(productDetails: details);
    }

    try {
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      lastError = '$e';
      _analytics?.log('purchase_error', {'plan': plan.id, 'reason': '$e'});
      notifyListeners();
      return false;
    }
  }

  /// Upgrade/downgrade without a lapse: Play handles proration per [mode].
  /// `withTimeProration` credits the unused time — the right default for a
  /// monthly → annual switch, which is the upgrade we actually care about.
  Future<bool> switchPlan(
    ProPlan target, {
    required GooglePlayPurchaseDetails currentPurchase,
    ReplacementMode mode = ReplacementMode.withTimeProration,
  }) async {
    if (!available) return false;
    _analytics?.log('purchase_started', {'plan': target.id, 'kind': 'change_plan'});

    final details = await _detailsFor(target);
    if (details == null || details is! GooglePlayProductDetails) return false;

    final param = GooglePlayPurchaseParam(
      productDetails: details,
      offerToken: target.offerToken,
      changeSubscriptionParam: ChangeSubscriptionParam(oldPurchaseDetails: currentPurchase, replacementMode: mode),
    );
    try {
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<ProductDetails?> _detailsFor(ProPlan plan) async {
    final response = await _iap.queryProductDetails({plan.id});
    if (response.productDetails.isEmpty) return null;

    // Play hands us one entry per offer; pick the one matching our chosen offer
    // (falling back to the first subscription offer of that product).
    for (final d in response.productDetails) {
      if (d.id != plan.id) continue;
      if (!plan.subscription) return d;
      if (d is GooglePlayProductDetails) {
        final offers = d.productDetails.subscriptionOfferDetails ?? const [];
        final index = d.subscriptionIndex;
        if (index != null && index < offers.length) {
          final offer = offers[index];
          if (plan.offerId == null || offer.offerId == plan.offerId) return d;
        }
        continue;
      }
      return d;
    }
    return response.productDetails.first;
  }

  // ------------------------------------------------------------------- restore
  /// Restores on a new device or a reinstall. Play replays entitlements through
  /// the purchase stream with `PurchaseStatus.restored`.
  /// Asks Play to replay the user's purchases. Every replayed purchase arrives on
  /// the purchase stream and is then verified server-side like any other, so
  /// restoring on a new device grants nothing by itself.
  Future<void> restore() async {
    if (!available) return;
    _analytics?.log('restore_started');
    try {
      await _iap.restorePurchases();
    } catch (e) {
      lastError = '$e';
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- purchase flow
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // e.g. a bank transfer that has not cleared. Grant nothing yet.
          _inFlight[purchase.productID] = purchase;
          _analytics?.log('purchase_pending', {'product': purchase.productID});
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final isRestore = purchase.status == PurchaseStatus.restored;
          final token = purchase.verificationData.serverVerificationData;

          // 1. Acknowledge FIRST. Play auto-refunds anything unacknowledged after
          //    3 days, so this must never sit behind a network call.
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          // 2. Record what Play told us, as an explicitly UNVERIFIED entitlement.
          //    It grants nothing: `Entitlement.active` requires the server's
          //    confirmation, so a recognised product id alone is never enough.
          final provisional = Entitlement.provisional(
            productId: purchase.productID,
            purchaseToken: token,
            purchasedAt: _dateOf(purchase) ?? DateTime.now(),
            trial: purchase.productID != 'track_pro_lifetime',
          ).copyWith(source: isRestore ? 'restore' : 'play');
          _awaitingVerification[token] = provisional;
          _analytics?.log(isRestore ? 'restore_completed' : 'purchase_completed', {
            'product': purchase.productID,
            'trial': provisional.inTrial,
            'source': provisional.source,
            'stage': 'awaiting_server',
          });
          if (provisional.inTrial) _analytics?.log('trial_started', {'product': purchase.productID});
          notifyListeners();

          // 3. Ask the server. Only a `valid` verdict unlocks anything.
          await _verify(productId: purchase.productID, token: token);
          break;

        case PurchaseStatus.canceled:
          _analytics?.log('purchase_canceled', {'product': purchase.productID});
          lastError = null;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          final code = purchase.error?.code;
          lastError = _messageFor(code) ?? purchase.error?.message ?? 'Purchase failed';
          _analytics?.log('purchase_error', {'product': purchase.productID, 'code': '$code'});
          // Even on error we must finish the transaction, or it blocks retries.
          if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
          notifyListeners();
          break;
      }
    }
  }

  /// Server-side verification — the only path that can make an entitlement
  /// active.
  ///
  /// Outcomes, all handled explicitly:
  /// - `valid`  → grant Pro, store the server's expiry/auto-renew/grace values;
  /// - `pending` → keep waiting, grant nothing, tell the user why;
  /// - `rejected` → drop the pending claim and log it (refund, cancelled order,
  ///   wrong package, unknown product);
  /// - `unreachable` → keep the claim queued and retry on the next launch,
  ///   resume or manual retry. **Never** grants access.
  Future<void> _verify({required String productId, required String token}) async {
    final verifier = _verifier;
    if (verifier == null) {
      lastVerifyOutcome = 'no_verifier_configured';
      notifyListeners();
      return;
    }
    if (token.isEmpty) {
      lastVerifyOutcome = 'empty_token';
      _awaitingVerification.remove(token);
      notifyListeners();
      return;
    }

    try {
      final result = await verifier.verify(productId: productId, purchaseToken: token, packageName: packageName);
      lastVerifyOutcome = result.reason ?? (result.valid ? 'valid' : 'invalid');

      if (result.valid) {
        final base =
            _awaitingVerification.remove(token) ??
            Entitlement.provisional(
              productId: productId,
              purchaseToken: token,
              purchasedAt: DateTime.now(),
              trial: productId != 'track_pro_lifetime',
            );
        _apply(
          base.copyWith(
            isPro: true,
            pending: false,
            verified: true,
            // Server-supplied facts win over locally derived ones.
            expiresAt: result.expiresAt ?? base.expiresAt,
            trialEndsAt: result.trialEndsAt ?? base.trialEndsAt,
            autoRenew: result.autoRenew ?? base.autoRenew,
            inGracePeriod: result.inGracePeriod,
            verifiedAt: DateTime.now(),
            source: 'server',
          ),
          persistNow: true,
        );
        _analytics?.log('purchase_verified', {'product': productId});
        return;
      }

      if (result.pending) {
        // Paid, not settled. Show the wait; grant nothing.
        final base = _awaitingVerification[token];
        if (base != null) {
          _awaitingVerification[token] = base.copyWith(pending: true, verified: false);
        }
        notifyListeners();
        return;
      }

      if (!result.reachable) {
        // Backend down or offline: keep the claim, retry later, grant nothing.
        notifyListeners();
        return;
      }

      // The server reached a verdict and it was "no". Drop the claim.
      _awaitingVerification.remove(token);
      _analytics?.log('purchase_error', {'product': productId, 'reason': result.reason ?? 'rejected'});
      notifyListeners();
    } catch (e) {
      lastVerifyOutcome = 'verify_threw';
      // Never surface the exception text: it can contain the endpoint or HTTP
      // details, and never the token (which we do not log anywhere).
      notifyListeners();
    }
  }

  /// Retry any queued verification. Called on resume, on demand from Settings,
  /// and after a period of being offline.
  Future<void> retryPendingVerification() async {
    final queued = Map<String, Entitlement>.from(_awaitingVerification);
    for (final e in queued.entries) {
      await _verify(productId: e.value.productId ?? '', token: e.key);
    }
  }

  /// Re-checks the stored entitlement with the backend. Called on launch and on
  /// every resume, and it is how a refund, a cancellation, an account hold or an
  /// expiry reaches the device without a webhook into the app.
  ///
  /// The three outcomes are deliberately different:
  /// - confirmed → refresh expiry/auto-renew, keep Pro;
  /// - rejected **and reachable** → drop to free immediately (a refund should not
  ///   keep working until the cache expires);
  /// - unreachable → keep the last confirmed state; `Entitlement.active` decides
  ///   how long that lasts, and the next successful check overwrites it.
  Future<void> reconcile() async {
    final token = _entitlement.purchaseToken;
    final verifier = _verifier;
    if (token == null || verifier == null) return;

    final result = await verifier.verify(
      productId: _entitlement.productId ?? '',
      purchaseToken: token,
      packageName: packageName,
    );
    lastVerifyOutcome = result.reason ?? (result.valid ? 'valid' : 'invalid');

    if (result.valid) {
      _apply(
        _entitlement.copyWith(
          isPro: true,
          pending: false,
          verified: true,
          verifiedAt: DateTime.now(),
          expiresAt: result.expiresAt ?? _entitlement.expiresAt,
          trialEndsAt: result.trialEndsAt ?? _entitlement.trialEndsAt,
          autoRenew: result.autoRenew ?? _entitlement.autoRenew,
          inGracePeriod: result.inGracePeriod,
          source: 'server',
        ),
        persistNow: true,
      );
      return;
    }

    if (!result.reachable) {
      // Unknown, not disproven. Do not touch the stored state.
      notifyListeners();
      return;
    }

    if (result.pending) {
      _apply(_entitlement.copyWith(verified: false, pending: true), persistNow: true);
      return;
    }

    // The server says this purchase is not valid: revoked, refunded or expired.
    _apply(Entitlement.free, persistNow: true);
    _analytics?.log('purchase_error', {'reason': result.reason ?? 'server_rejected_on_reconcile'});
  }

  /// Re-verification entry point for the UI ("Check purchase again").
  Future<void> recheck() async {
    await retryPendingVerification();
    await reconcile();
  }

  /// Call when the app resumes: an entitlement that expired while backgrounded
  /// must not survive the resume.
  /// Local expiry check for resume: an entitlement that lapsed while the app was
  /// backgrounded must not survive the resume, even if the network is down.
  void reevaluate() {
    if (!_entitlement.isPro) return;
    if (_entitlement.active) return;
    // Keep the token and the verified flag: this is an expiry, not a revocation,
    // and a re-subscribe should be able to restore instantly.
    _apply(_entitlement.copyWith(isPro: _entitlement.isLifetime, pending: false), persistNow: true);
  }

  // ------------------------------------------------------------------ plumbing
  void _apply(Entitlement ent, {bool persistNow = true}) {
    _entitlement = ent;
    if (persistNow) _updates.add(ent);
    notifyListeners();
  }

  DateTime? _dateOf(PurchaseDetails p) {
    final raw = p.transactionDate;
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Play error codes worth translating — the rest fall back to Play's message.
  String? _messageFor(BillingResponse? code) {
    switch (code) {
      case BillingResponse.userCanceled:
        return null; // not an error; the user chose to back out
      case BillingResponse.itemAlreadyOwned:
        return 'You already own this — try Restore purchases.';
      case BillingResponse.billingUnavailable:
        return 'Google Play is unavailable. Check your connection and try again.';
      case BillingResponse.itemUnavailable:
        return 'This plan is not available for your account right now.';
      case BillingResponse.developerError:
        return 'Play could not process that. Please try again.';
      case BillingResponse.serviceDisconnected:
        return 'Lost connection to Google Play. Reopen the app and retry.';
      default:
        return null;
    }
  }

  /// Opens Play's subscription centre — the only place a user can cancel, and
  /// required to be reachable from inside the app (Play policy).
  ///
  /// Defaults to this service's own [packageName]: a literal here used to drift
  /// from the applicationId in `android/app/build.gradle.kts`, and a manage link
  /// pointed at the wrong package is a cancel flow that silently leads nowhere.
  String manageUrl({String? packageName}) {
    final pkg = packageName ?? this.packageName;
    final sku = _entitlement.productId ?? ProConfig.plans.first.id;
    return 'https://play.google.com/store/account/subscriptions?sku=$sku&package=$pkg';
  }

  /// Funnel-friendly summary for the paywall's "already subscribed?" path.
  bool get hasAnyPurchase => _entitlement.purchaseToken != null;

  @override
  void dispose() {
    _sub?.cancel();
    _updates.close();
    super.dispose();
  }
}

/// ---------------------------------------------------------------------------
/// Verification seam.
/// ---------------------------------------------------------------------------
/// [PurchaseVerifier] is the single contract that can turn a Play purchase into
/// Pro; [HttpPurchaseVerifier] implements it against a backend that calls
/// `purchases.subscriptionsv2.get` (subscriptions) or `purchases.products.get`
/// (one-time) with a service account. See MONETIZATION.md for the exact flow,
/// RTDN handling and the acknowledgement rules.
///
/// Note the parameter is `packageName`, not a client-side signature: the client
/// holds no key that could prove a purchase, which is precisely why the verdict
/// has to come from a server.
class VerifyResult {
  const VerifyResult({
    required this.valid,
    this.expiresAt,
    this.trialEndsAt,
    this.autoRenew,
    this.inGracePeriod = false,
    this.pending = false,
    this.reason,
    this.reachable = true,
  });

  /// The server confirmed the purchase against the Play Developer API.
  final bool valid;
  final DateTime? expiresAt;
  final DateTime? trialEndsAt;
  final bool? autoRenew;
  final bool inGracePeriod;

  /// Purchase exists but has not cleared (e.g. a slow payment method).
  final bool pending;

  final String? reason;

  /// False when we could not reach the server at all.
  ///
  /// This distinction is the difference between "revoke this entitlement" and
  /// "try again later". Treating an outage as a rejection would lock out every
  /// paying user the moment the backend hiccups; treating a rejection as an
  /// outage would never revoke a refund.
  final bool reachable;

  static const VerifyResult invalid = VerifyResult(valid: false, reason: 'invalid');

  /// The server was not reachable. Not a rejection — retry later.
  static const VerifyResult unreachable = VerifyResult(valid: false, reachable: false, reason: 'unreachable');

  /// The server reached its verdict but says the purchase is not (yet) good.
  static VerifyResult rejected(String reason) => VerifyResult(valid: false, reason: reason);

  /// The server says the purchase is real and not yet settled.
  static VerifyResult pendingPurchase({DateTime? expiresAt}) =>
      VerifyResult(valid: false, pending: true, expiresAt: expiresAt, reason: 'pending');
}

/// Contract for the entity that can confirm a purchase really was paid for.
///
/// There is exactly one production implementation ([HttpPurchaseVerifier]) and
/// exactly one rule: **only a `valid: true` result from a reachable server may
/// make an entitlement active.** Everything else leaves the user on the free
/// plan while the app retries.
abstract class PurchaseVerifier {
  const PurchaseVerifier();

  Future<VerifyResult> verify({required String productId, required String purchaseToken, required String packageName});
}

/// **Development stub. Cannot run in a release build.**
///
/// It reports any known product id as valid, which is precisely the behaviour
/// that must never reach users: anyone could edit the APK and grant themselves
/// Pro. It exists so the paywall, the gates and the entitlement plumbing can be
/// exercised without a backend, and it throws in release rather than pretending.
class LocalOnlyVerifier extends PurchaseVerifier {
  const LocalOnlyVerifier();

  @override
  Future<VerifyResult> verify({
    required String productId,
    required String purchaseToken,
    required String packageName,
  }) async {
    if (kReleaseMode) {
      throw StateError(
        'LocalOnlyVerifier is a development stub and must never run in a release build. '
        'Wire HttpPurchaseVerifier to a deployed /billing/verify endpoint instead.',
      );
    }
    if (ProConfig.planForProduct(productId) == null) return VerifyResult.invalid;
    return VerifyResult(
      valid: true,
      autoRenew: ProConfig.planForProduct(productId)!.subscription,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      reason: 'dev_stub',
    );
  }
}

/// The production verifier: POSTs the purchase token to our backend, which calls
/// the Google Play Developer API with a service account.
///
/// Dependency-free on purpose (`dart:io` only): one HTTP call is not worth
/// another package in the release binary, and the smaller the surface that can
/// grant Pro, the easier it is to review.
///
/// **Fails closed.** Timeouts, 5xx, malformed JSON and DNS failures all return
/// [VerifyResult.unreachable] — never `valid` — so a broken backend cannot hand
/// out Pro, and a spoofed response from a proxy needs the same secret material
/// the server has anyway (the client trusts only its own TLS channel).
class HttpPurchaseVerifier extends PurchaseVerifier {
  HttpPurchaseVerifier({
    required this.endpoint,
    this.bearerTokenProvider,
    this.timeout = const Duration(seconds: 10),
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  /// Null when `TRACK_VERIFY_URL` was not supplied at build time. A null
  /// endpoint means verification cannot happen, which means Pro cannot be
  /// granted — the correct outcome for a build with no backend.
  final Uri? endpoint;

  /// Optional additional credential (Play Integrity / App Check token, or a
  /// rotated API key fetched at runtime). Never a secret compiled into the APK.
  final Future<String?> Function()? bearerTokenProvider;

  final Duration timeout;
  final HttpClient _client;

  bool get isConfigured => endpoint != null && endpoint!.hasScheme && endpoint!.host.isNotEmpty;

  @override
  Future<VerifyResult> verify({
    required String productId,
    required String purchaseToken,
    required String packageName,
  }) async {
    final url = endpoint;
    if (url == null || !isConfigured) {
      // No backend configured: report unreachable so the caller keeps the
      // purchase pending and retries, rather than inventing an entitlement.
      return VerifyResult.unreachable;
    }

    // Never log the token. The product id and package are safe.
    try {
      final request = await _client.postUrl(url).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final bearer = await bearerTokenProvider?.call();
      if (bearer != null && bearer.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }

      request.write(jsonEncode({'productId': productId, 'purchaseToken': purchaseToken, 'packageName': packageName}));

      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);

      if (response.statusCode >= 500 || response.statusCode == 408 || response.statusCode == 429) {
        // Server trouble is not a verdict about the purchase.
        return VerifyResult.unreachable;
      }
      if (response.statusCode != 200) {
        return VerifyResult.rejected('http_${response.statusCode}');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) return VerifyResult.rejected('bad_payload');

      final valid = decoded['valid'] == true;
      if (!valid) {
        // A server-side "pending" (payment not settled) is distinct from "no".
        if (decoded['pending'] == true) {
          return VerifyResult.pendingPurchase(expiresAt: _parseDate(decoded['expiresAt']));
        }
        return VerifyResult.rejected((decoded['reason'] as String?) ?? 'rejected');
      }

      return VerifyResult(
        valid: true,
        expiresAt: _parseDate(decoded['expiresAt']),
        trialEndsAt: _parseDate(decoded['trialEndsAt']),
        autoRenew: decoded['autoRenew'] as bool?,
        inGracePeriod: decoded['inGracePeriod'] as bool? ?? false,
        reason: 'server',
      );
    } catch (_) {
      // DNS, TLS, timeout, malformed JSON — all "could not ask".
      return VerifyResult.unreachable;
    }
  }

  static DateTime? _parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

  void dispose() => _client.close(force: true);
}

/// Snapshot of the current purchase for support ("what did I buy?").
String purchaseDebugJson(PurchaseDetails p) => jsonEncode({
  'product': p.productID,
  'status': p.status.name,
  'transactionDate': p.transactionDate,
  'tokenTail': p.verificationData.serverVerificationData.length > 8
      ? p.verificationData.serverVerificationData.substring(p.verificationData.serverVerificationData.length - 8)
      : p.verificationData.serverVerificationData,
});
