/// ============================================================================
/// Track Pro — the single source of truth for monetisation.
/// ============================================================================
///
/// Everything that decides "free vs Pro" lives in this file, so pricing or
/// packaging changes never require touching a screen. The paywall UI, the locks
/// scattered through the app, the widget snapshot and the tests all read from
/// here.
///
/// ## The split, and why
///
/// The product thesis is lock-in through **accumulated data**. So the one thing
/// we do not sell is access to your own data — that would poison reviews and
/// invite a "hold my data hostage" narrative. Instead:
///
/// | Free forever                          | Pro                                        |
/// |---------------------------------------|--------------------------------------------|
/// | 3 trackers                            | all 10+ trackers, unlimited custom ones     |
/// | last 7 days of history                | full history, forever                       |
/// | today's rings, streaks, badges        | patterns, correlations, heatmaps, 90d range |
/// | daily check-in reminder               | streak saver, weekly report, smart nudges   |
/// | home-screen widget (1 ring)           | widget with 3 rings + Wear tile             |
/// | manual logging, **export is free**    | Health Connect auto-sync (steps/sleep/kg)   |
/// | Focus Lock: all 3 modes, up to 3 apps | unlimited blocked apps, profiles, schedules |
/// | Focus history: last 7 sessions        | full history + focus patterns               |
///
/// Depth of history is the paid axis: it is exactly the thing that makes the app
/// more valuable (and harder to leave) the longer you use it, which makes it a
/// purchase people *want* to make rather than one they resent.
library;

class ProConfig {
  const ProConfig._();

  /// Free-tier ceilings. Change these in one place; the whole app follows.
  static const int freeTrackerLimit = 3;
  static const int freeHistoryDays = 7;

  /// Apps a free session may restrict at once.
  ///
  /// Three, because Focus Lock's timer is the feature and blocking is the
  /// amplifier: a free user must be able to run a real, fully-functional focus
  /// session — including blocking the apps that actually distract them — and decide
  /// whether it works for them. What is paid is *scale*: a whole-procrastination
  /// block list, saved profiles, scheduled sessions and the pattern analysis over
  /// finished sessions.
  static const int freeBlockedApps = 3;

  /// Sessions of history a free user sees. The live session and its summary are
  /// never gated: the session a person just ran is theirs, immediately.
  static const int freeFocusHistorySessions = 7;

  /// Commitments (habits) the free tier can run at once.
  ///
  /// Deliberately generous: the habit loop is the product, and a person with five
  /// commitments is not a freeloader — they are the user the app is for. Pro adds
  /// *advanced* commitments and templates, never the ability to keep your own
  /// record. Lowering this is not a pricing tweak; it is a product decision that
  /// would break the promise the free tier makes.
  static const int freeCommitmentLimit = 5;

  /// Length of the store-configured free trial (must match the Play offer).
  static const int trialDays = 7;

  /// Shown only when the store is unreachable (dev builds, screenshots). In
  /// production the paywall always renders Play's localized `price` string —
  /// never a hardcoded number, or you will show ₹ to someone in Berlin.
  static const String fallbackMonthly = '₹399';
  static const String fallbackAnnual = '₹2,499';
  static const String fallbackLifetime = '₹4,999';

  /// The catalogue. `productId`s must match Play Console exactly.
  static const List<ProPlan> plans = <ProPlan>[
    ProPlan(
      id: 'track_pro_monthly',
      subscription: true,
      kind: PlanKind.monthly,
      title: 'Monthly',
      blurb: 'Flexible, cancel anytime',
      fallbackPrice: fallbackMonthly,
      fallbackPeriod: '/month',
      trialDays: trialDays,
    ),
    ProPlan(
      id: 'track_pro_annual',
      subscription: true,
      kind: PlanKind.annual,
      title: 'Annual',
      blurb: '7 days free, then billed yearly',
      fallbackPrice: fallbackAnnual,
      fallbackPeriod: '/year',
      trialDays: trialDays,
      badge: 'SAVE 48%',
      highlighted: true,
    ),
    ProPlan(
      id: 'track_pro_lifetime',
      subscription: false,
      kind: PlanKind.lifetime,
      title: 'Lifetime',
      blurb: 'One payment, yours forever',
      fallbackPrice: fallbackLifetime,
      fallbackPeriod: ' once',
    ),
  ];

  /// The Play Console base-plan id we attach the free trial to. Play delivers a
  /// separate `GooglePlayProductDetails` per offer, so we pick by this id.
  static const String trialOfferId = 'free-trial-7d';
  static const String annualBasePlanId = 'annual-auto';
  static const String monthlyBasePlanId = 'monthly-auto';

  /// The base-plan ids Play reports on some surfaces (and on RTDN), mapped to the
  /// product they belong to. They must match `android`-side Play Console
  /// configuration exactly — see `docs/PLAY_CHECKLIST.md`.
  static const Map<String, PlanKind> basePlanAliases = <String, PlanKind>{
    monthlyBasePlanId: PlanKind.monthly,
    annualBasePlanId: PlanKind.annual,
  };

  /// Resolves a Play product id (or a configured base-plan id) to its plan.
  ///
  /// **Exact matching, deliberately.** This used to fall back to substring
  /// guessing (`productId.contains('forever')`, `'monthly'`, …), so any foreign
  /// sku that happened to contain one of those words resolved to a Track Pro plan
  /// — and `Entitlement.provisional` and `LocalOnlyVerifier` both key off this
  /// function. An id that is not ours must resolve to `null`, which is what makes
  /// "unknown product grants nothing" true rather than a hope.
  static ProPlan? planForProduct(String productId) {
    for (final p in plans) {
      if (p.id == productId) return p;
    }
    final alias = basePlanAliases[productId];
    if (alias == null) return null;
    return plans.firstWhere((p) => p.kind == alias);
  }

  /// Benefit list for the paywall. Order matters: the least controversial first,
  /// the "aha" (patterns) in the middle, the practical (sync/widgets) last.
  static const List<ProBenefit> benefits = <ProBenefit>[
    ProBenefit('🧩', 'Every tracker, unlimited', 'Free keeps 3. Pro unlocks all 10 — plus custom trackers.'),
    ProBenefit('📈', 'Your full history, forever', 'Free shows 7 days. Pro shows every day you have ever logged.'),
    ProBenefit(
      '🔗',
      'Patterns no single app can find',
      'Sleep ⇄ mood ⇄ spending correlations, heatmaps, 90-day trends.',
    ),
    ProBenefit('❤️', 'Steps, sleep & weight auto-sync', 'Health Connect fills them in — zero-effort tracking.'),
    ProBenefit('🔥', 'Streak saver & weekly report', 'A nudge only when a streak is genuinely about to break.'),
    ProBenefit('📱', 'Widget with all three rings', 'Plus the Wear OS tile, on your watch.'),
    ProBenefit(
      '🎯',
      'Focus Lock, without limits',
      'Every mode is free. Pro covers your whole app list in one session, saves profiles, '
          'schedules deep focus, and shows when your focus actually holds.',
    ),
  ];

  /// Trust lines under the CTA. These are conversion *and* review-score work.
  /// Copy shown when a commitment gate is hit. States the ceiling in the user's
  /// terms and repeats the promise that their records are never withheld.
  static const String commitmentCeilingCopy =
      'Pro removes the routine limit and adds recovery planning. Your existing routines and '
      'every logged day stay yours either way.';

  static const List<String> trustLines = <String>[
    'Cancel anytime in Google Play — no email, no hoops',
    'Export every entry, free, forever. Your data is yours.',
    'One subscription covers your phone and your watch',
  ];

  static ProPlan get highlighted => plans.firstWhere((p) => p.highlighted, orElse: () => plans.first);

  /// Builds the "monthly equivalent" line, e.g. "≈ ₹208/month, billed yearly".
  /// Uses real store prices when available, otherwise the dev fallback.
  static String? subLineFor(ProPlan plan) {
    if (plan.kind != PlanKind.annual) return null;
    final raw = plan.rawPrice;
    if (raw == null) return 'Billed yearly · cancel anytime';
    final perMonth = raw / 12;
    final symbol = plan.currencySymbol ?? '';
    // No decimal places: this line exists to make the annual look like a whole
    // number of months, and "≈ ₹208.25/month" argues with itself. (An earlier
    // revision had `perMonth < 100 ? 0 : 0` here — a ternary whose two branches
    // were the same number, i.e. dead code posing as a rounding rule.)
    return '≈ $symbol${perMonth.toStringAsFixed(0)}/month, billed yearly';
  }

  // ------------------------------------------------------------------ policy
  // Pure functions over the tier. `AppState` delegates to these, and the tests
  // exercise them directly — a freemium gate that is only testable with a live
  // database is a gate that will eventually ship broken.

  /// Can one more tracker be added?
  static bool canAddTracker({required bool isPro, required int active}) => isPro || active < freeTrackerLimit;

  /// How many days of history this tier can see.
  static int historyWindowDays({required bool isPro, required int available}) =>
      isPro ? available : (available < freeHistoryDays ? available : freeHistoryDays);

  /// Is `daysAgo` past the free window? Used to draw lock markers rather than
  /// silently truncating a chart.
  static bool isHistoryLocked({required bool isPro, required int daysAgo}) => !isPro && daysAgo >= freeHistoryDays;

  /// Rings drawn by the home-screen widget and the Wear tile.
  static int widgetRings({required bool isPro}) => isPro ? 3 : 1;

  /// Which paywall placement, if any, a given lock should open. Kept next to the
  /// policy so a lock and its trigger can never drift apart.
  static PaywallTrigger? triggerFor(String gate) => switch (gate) {
    'tracker_limit' => PaywallTrigger.trackerLimit,
    'commitment_limit' => PaywallTrigger.commitmentLimit,
    'history' => PaywallTrigger.historyLock,
    'insights' => PaywallTrigger.insightsLock,
    'health' => PaywallTrigger.healthSync,
    'streak' => PaywallTrigger.streakSave,
    'streak_save' => PaywallTrigger.streakSave,
    'focus_apps' => PaywallTrigger.focusApps,
    'focus_profiles' => PaywallTrigger.focusProfiles,
    'focus_schedules' => PaywallTrigger.focusSchedules,
    'focus_analytics' => PaywallTrigger.focusAnalytics,
    _ => null,
  };

  static bool isProOnly(String feature) => <String>{
    'insights.patterns',
    'insights.correlations',
    'insights.heatmap',
    'insights.range90',
    'history.full',
    'trackers.more',
    'commitments.advanced',
    'health.sync',
    'notifications.streakSaver',
    'notifications.weekly',
    'widget.threeRings',
    'wear.tile',
    // Focus Lock. Note what is *not* here: the modes themselves, the timer, the
    // session summary, the app picker, and deleting your own sessions. Those are
    // free in every mode, because a habit app that charges to block the thing you
    // are avoiding has its incentives backwards.
    'focus.unlimitedApps',
    'focus.profiles',
    'focus.schedules',
    'focus.analytics',
  }.contains(feature);
}

enum PlanKind { monthly, annual, lifetime }

/// A purchasable plan, enriched at runtime with the store's localized price.
class ProPlan {
  const ProPlan({
    required this.id,
    required this.subscription,
    required this.kind,
    required this.title,
    required this.blurb,
    required this.fallbackPrice,
    required this.fallbackPeriod,
    this.trialDays = 0,
    this.badge,
    this.highlighted = false,
    this.price,
    this.rawPrice,
    this.currencySymbol,
    this.currencyCode,
    this.offerId,
    this.offerToken,
    this.basePlanId,
  });

  final String id;
  final bool subscription;
  final PlanKind kind;
  final String title;
  final String blurb;
  final String fallbackPrice;
  final String fallbackPeriod;
  final int trialDays;
  final String? badge;
  final bool highlighted;

  // --- filled in from the store -------------------------------------------
  final String? price; // "₹2,499" — always prefer this
  final double? rawPrice;
  final String? currencySymbol;
  final String? currencyCode;
  final String? offerId; // "free-trial-7d" when Play returned that offer
  final String? offerToken; // required to launch the billing flow
  final String? basePlanId;

  String get displayPrice => price ?? fallbackPrice;
  String get displayPeriod => price == null ? fallbackPeriod : periodFor(kind);
  bool get hasTrial => subscription && trialDays > 0;

  static String periodFor(PlanKind kind) {
    switch (kind) {
      case PlanKind.monthly:
        return '/month';
      case PlanKind.annual:
        return '/year';
      case PlanKind.lifetime:
        return ' once';
    }
  }

  /// The one line that must be legible at a glance, and legally accurate.
  String ctaFor() {
    if (hasTrial) return 'Start $trialDays-day free trial';
    if (kind == PlanKind.lifetime) return 'Buy once · $displayPrice';
    return 'Continue · $displayPrice$displayPeriod';
  }

  /// What the purchase will do, in time order, including how to get out of it.
  ///
  /// The cancel clause is not decoration: Play requires a trial to state how to
  /// avoid the first charge, and `test/billing_test.dart` pins that this string
  /// says so. Copy that promises a trial without saying it can be cancelled is
  /// the shape of a refund dispute.
  String trialTimeline() {
    if (!hasTrial) {
      return kind == PlanKind.lifetime ? 'No subscription. No renewal.' : 'Billed $displayPrice$displayPeriod';
    }
    return 'Free today · cancel anytime before day $trialDays · reminder on day ${trialDays - 3} · '
        '$displayPrice$displayPeriod from day $trialDays';
  }

  ProPlan copyWith({
    String? price,
    double? rawPrice,
    String? currencySymbol,
    String? currencyCode,
    String? offerId,
    String? offerToken,
    String? basePlanId,
  }) {
    return ProPlan(
      id: id,
      subscription: subscription,
      kind: kind,
      title: title,
      blurb: blurb,
      fallbackPrice: fallbackPrice,
      fallbackPeriod: fallbackPeriod,
      trialDays: offerId == ProConfig.trialOfferId ? ProConfig.trialDays : trialDays,
      badge: badge,
      highlighted: highlighted,
      price: price ?? this.price,
      rawPrice: rawPrice ?? this.rawPrice,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      offerId: offerId ?? this.offerId,
      offerToken: offerToken ?? this.offerToken,
      basePlanId: basePlanId ?? this.basePlanId,
    );
  }
}

class ProBenefit {
  const ProBenefit(this.emoji, this.title, this.body);

  final String emoji;
  final String title;
  final String body;
}

/// ---------------------------------------------------------------------------
/// Entitlement — the answer to "is this user Pro right now?".
/// ---------------------------------------------------------------------------
///
/// Deliberately conservative — **fail closed**:
/// - **nothing is Pro until the server has verified the purchase token.** A
///   recognised product id is not evidence of payment;
/// - a `pending` purchase (UPI, net-banking, slow card) grants nothing until it
///   clears;
/// - a subscription is active until `expiresAt`, plus a bounded offline grace so
///   a flight does not lock a paying user out of their own dashboard;
/// - a subscription whose verification is older than [maxStaleDays] stops
///   counting, so a cached file edited on a rooted device cannot become a
///   permanent grant — the next successful check overwrites it, and until then it
///   is not honoured;
/// - a **lifetime** purchase never expires and needs verifying only once.
///
/// The server (Play Developer API) is the authority; this object is the offline
/// cache that keeps the app instant and honest about what it actually knows.
class Entitlement {
  const Entitlement({
    required this.isPro,
    this.planId,
    this.productId,
    this.expiresAt,
    this.trialEndsAt,
    this.autoRenew = false,
    this.purchaseToken,
    this.source = 'none',
    this.verified = false,
    this.verifiedAt,
    this.pending = false,
    this.inGracePeriod = false,
  });

  final bool isPro;
  final String? planId;
  final String? productId;
  final DateTime? expiresAt;
  final DateTime? trialEndsAt;
  final bool autoRenew;
  final String? purchaseToken;

  /// play | cache | restore | dev | none
  final String source;

  /// True once the backend confirmed the token with the Play Developer API.
  ///
  /// This is the only field that can make [active] true, and it is written **only**
  /// by `BillingService` from a server response — never from a local heuristic.
  final bool verified;

  /// When the server last confirmed this entitlement.
  final DateTime? verifiedAt;
  final bool pending;
  final bool inGracePeriod;

  static const Entitlement free = Entitlement(isPro: false);

  /// Local, bounded tolerance for a delayed renewal notification while offline.
  static const Duration offlineGrace = Duration(days: 3);

  /// How long a *subscription* verification is trusted without a fresh check.
  ///
  /// Every launch and resume re-verifies, so this only matters to a device that
  /// has been offline for a week. It exists so that editing the cached
  /// entitlement on a rooted device cannot outlive the next successful check.
  static const Duration maxStaleDays = Duration(days: 7);

  bool get inTrial {
    final end = trialEndsAt;
    return isPro && end != null && DateTime.now().isBefore(end);
  }

  int get trialDaysLeft {
    final end = trialEndsAt;
    if (end == null) return 0;
    final left = end.difference(DateTime.now()).inHours / 24;
    return left <= 0 ? 0 : left.ceil();
  }

  bool get isLifetime => planId != null && ProConfig.planForProduct(planId!)?.kind == PlanKind.lifetime;

  /// Re-evaluated on every launch, on every purchase-stream event, and on
  /// resume from background — cheap enough to be paranoid.
  bool get active {
    if (!isPro) return false;

    // 1. A pending purchase has not been paid for yet (UPI, net-banking and slow
    //    cards are routine). Granting here gives away access per failed payment.
    if (pending) return false;

    // 2. Fail closed: without a server confirmation this is a claim, not a right.
    if (!verified) return false;

    // 3. Lifetime: verified once, valid forever. There is no renewal to miss and
    //    nothing for a stale cache to hide.
    if (isLifetime) return true;

    // 4. Subscription freshness: a cached grant that has not been re-checked in
    //    a week is not honoured, so a tampered file cannot become permanent.
    final checkedAt = verifiedAt;
    if (checkedAt == null) return false;
    if (DateTime.now().isAfter(checkedAt.add(maxStaleDays))) return false;

    // 5. Expiry, plus the short offline grace for a delayed renewal.
    final end = expiresAt;
    if (end == null) return false; // a subscription must carry an expiry
    return DateTime.now().isBefore(end.add(offlineGrace));
  }

  /// Why [active] is false, in a form the UI can explain. Null when Pro.
  String? get inactiveReason {
    if (active) return null;
    if (!isPro) return null;
    if (pending) return 'Waiting for Google Play to confirm the payment.';
    if (!verified) return 'This purchase has not been confirmed with Google Play yet.';
    if (!isLifetime) {
      final checkedAt = verifiedAt;
      if (checkedAt == null) return 'This purchase has not been confirmed with Google Play yet.';
      if (DateTime.now().isAfter(checkedAt.add(maxStaleDays))) {
        return 'Connect to the internet once so this purchase can be re-confirmed.';
      }
      if (expiresAt == null || !DateTime.now().isBefore(expiresAt!.add(offlineGrace))) {
        return 'This subscription has expired.';
      }
    }
    return 'This purchase could not be confirmed.';
  }

  /// Human name of the active plan, for Settings.
  ///
  /// Carries the product name ("Track Pro Annual", not "Pro Annual"): Settings
  /// renders this as the plan headline with no surrounding title, and a bare
  /// "Pro" reads like a status rather than the plan someone is paying for.
  String get planTitle {
    final plan = planId == null ? null : ProConfig.planForProduct(planId!);
    if (plan == null) return 'Track Pro';
    if (isLifetime) return 'Track Pro Lifetime';
    if (inTrial) return 'Track Pro trial';
    return 'Track Pro ${plan.title}';
  }

  /// One line, always visible in Settings and on the paywall footer, and always
  /// telling the truth about what happens next. "Cancelled · access until 14 Nov"
  /// is a sentence that prevents support email; "Pro" on its own is not.
  String get statusLine {
    if (!isPro) return 'Free plan · ${ProConfig.freeTrackerLimit} trackers, ${ProConfig.freeHistoryDays}-day history';
    if (isLifetime) return 'Lifetime · yours forever';
    final plan = planId == null ? null : ProConfig.planForProduct(planId!);
    final name = plan?.title ?? 'Pro';
    if (inTrial) return '$name · trial, $trialDaysLeft days left';
    if (inGracePeriod) return '$name · billing issue — fix in Google Play';
    final end = expiresAt;
    if (end == null) return '$name · active';
    return autoRenew ? '$name · renews ${_fmtDate(end)}' : '$name · access until ${_fmtDate(end)}';
  }

  Entitlement copyWith({
    bool? isPro,
    String? planId,
    String? productId,
    DateTime? expiresAt,
    DateTime? trialEndsAt,
    bool? autoRenew,
    String? purchaseToken,
    String? source,
    bool? verified,
    DateTime? verifiedAt,
    bool? pending,
    bool? inGracePeriod,
  }) {
    return Entitlement(
      isPro: isPro ?? this.isPro,
      planId: planId ?? this.planId,
      productId: productId ?? this.productId,
      expiresAt: expiresAt ?? this.expiresAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      autoRenew: autoRenew ?? this.autoRenew,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      source: source ?? this.source,
      verified: verified ?? this.verified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      pending: pending ?? this.pending,
      inGracePeriod: inGracePeriod ?? this.inGracePeriod,
    );
  }

  Map<String, Object?> toJson() => {
    'isPro': isPro,
    'planId': planId,
    'productId': productId,
    'expiresAt': expiresAt?.toIso8601String(),
    'trialEndsAt': trialEndsAt?.toIso8601String(),
    'autoRenew': autoRenew,
    'purchaseToken': purchaseToken,
    'source': source,
    'verified': verified,
    'verifiedAt': verifiedAt?.toIso8601String(),
    'pending': pending,
    'inGracePeriod': inGracePeriod,
  };

  static Entitlement fromJson(Map<String, Object?> m) => Entitlement(
    isPro: m['isPro'] as bool? ?? false,
    planId: m['planId'] as String?,
    productId: m['productId'] as String?,
    expiresAt: _parse(m['expiresAt']),
    trialEndsAt: _parse(m['trialEndsAt']),
    autoRenew: m['autoRenew'] as bool? ?? false,
    purchaseToken: m['purchaseToken'] as String?,
    source: m['source'] as String? ?? 'cache',
    verified: m['verified'] as bool? ?? false,
    verifiedAt: _parse(m['verifiedAt']),
    pending: m['pending'] as bool? ?? false,
    inGracePeriod: m['inGracePeriod'] as bool? ?? false,
  );

  /// A purchase Play has accepted, **awaiting server confirmation**.
  ///
  /// This is what the client can honestly construct on its own: the product, the
  /// token and a provisional expiry derived from the plan period. It is
  /// deliberately `pending: true, verified: false`, so [active] returns false and
  /// no Pro feature unlocks until the backend confirms with the Play Developer
  /// API. Play's client API does not expose subscription expiry — only the server
  /// does — which is the whole reason this cannot be final.
  static Entitlement provisional({
    required String productId,
    required String purchaseToken,
    required DateTime purchasedAt,
    bool trial = false,
  }) {
    final plan = ProConfig.planForProduct(productId);
    if (plan == null) return free;
    if (plan.kind == PlanKind.lifetime) {
      return Entitlement(
        isPro: true,
        planId: plan.id,
        productId: productId,
        purchaseToken: purchaseToken,
        source: 'play',
        pending: true, // awaiting server confirmation; see class docs
      );
    }
    final base = trial ? purchasedAt.add(Duration(days: plan.trialDays)) : purchasedAt;
    final period = plan.kind == PlanKind.annual ? const Duration(days: 365) : const Duration(days: 30);
    return Entitlement(
      isPro: true,
      planId: plan.id,
      productId: productId,
      expiresAt: base.add(period),
      trialEndsAt: trial ? base : null,
      autoRenew: true,
      purchaseToken: purchaseToken,
      source: 'play',
      pending: true, // awaiting server confirmation; see class docs
    );
  }

  static DateTime? _parse(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

/// Where the paywall was opened from. Logged on every view, because placement is
/// the single biggest lever on trial conversion and you cannot tune what you
/// cannot see.
enum PaywallTrigger {
  settings,
  focusApps,
  focusProfiles,
  focusSchedules,
  focusAnalytics,
  trackerLimit,
  commitmentLimit,
  insightsLock,
  historyLock,
  healthSync,
  streakSave,
  widget,
  onboarding,
  softPrompt,
}

extension PaywallTriggerLabel on PaywallTrigger {
  String get key => name;
  String get title {
    switch (this) {
      case PaywallTrigger.trackerLimit:
        return 'Keep all your trackers in one place';
      case PaywallTrigger.commitmentLimit:
        return 'Room for every routine';
      case PaywallTrigger.insightsLock:
        return 'See what your data is telling you';
      case PaywallTrigger.historyLock:
        return 'Your history is worth keeping';
      case PaywallTrigger.healthSync:
        return 'Let steps and sleep fill themselves in';
      case PaywallTrigger.streakSave:
        return 'Protect the streak you have built';
      case PaywallTrigger.widget:
        return 'All three rings on your home screen';
      case PaywallTrigger.focusApps:
        return 'Block the whole list';
      case PaywallTrigger.focusProfiles:
        return 'Set it up once';
      case PaywallTrigger.focusSchedules:
        return 'Focus on a schedule';
      case PaywallTrigger.focusAnalytics:
        return 'See when focus actually works for you';
      case PaywallTrigger.softPrompt:
        // Deliberately not a number. This headline used to read "You have logged 12
        // days in a row" regardless of the user's actual streak — a fabricated
        // claim in the one place a user is most likely to notice it. The real
        // figure is the Momentum screen's job, where it comes from the engine.
        return 'Keep the run going';
      case PaywallTrigger.onboarding:
        return 'Start with everything unlocked';
      case PaywallTrigger.settings:
        return 'Pro';
    }
  }

  String get body {
    switch (this) {
      case PaywallTrigger.trackerLimit:
        return 'Free covers ${ProConfig.freeTrackerLimit} trackers. Pro removes the ceiling — every tracker, plus custom ones, in the same dashboard.';
      case PaywallTrigger.commitmentLimit:
        return ProConfig.commitmentCeilingCopy;
      case PaywallTrigger.insightsLock:
        return 'Two weeks of logged days is enough to find real patterns. Pro shows them: sleep against mood, spending against sleep, your strongest days.';
      case PaywallTrigger.historyLock:
        return 'Free keeps ${ProConfig.freeHistoryDays} days. Pro keeps every day you have ever logged — which is the whole point of tracking.';
      case PaywallTrigger.healthSync:
        return 'Pro pulls steps, sleep and weight from Health Connect, so three of your trackers fill themselves in.';
      case PaywallTrigger.streakSave:
        return 'A streak saver that nudges you before a streak breaks, and a weekly report that shows the run you are on.';
      case PaywallTrigger.widget:
        return 'Pro shows all three rings on your home screen, plus the Wear OS tile.';
      case PaywallTrigger.softPrompt:
        return 'That streak is now an asset. Pro keeps every day of it — the long trend is why it is worth protecting.';
      case PaywallTrigger.onboarding:
        return 'Every tracker, your full history, and the patterns underneath. 7 days on us.';
      case PaywallTrigger.focusApps:
        return 'Free focus sessions can cover ${ProConfig.freeBlockedApps} apps. Pro removes the ceiling, so one session can cover every app you open when you are avoiding work.';
      case PaywallTrigger.focusProfiles:
        return 'Save a rule set — mode, length and app list — and start it with one tap instead of setting it up again.';
      case PaywallTrigger.focusSchedules:
        return 'Put a deep focus session on a schedule: the reminder arrives at the time you chose, with one tap to start.';
      case PaywallTrigger.focusAnalytics:
        return 'Free shows your last ${ProConfig.freeFocusHistorySessions} sessions. Pro shows the pattern: which time of day your sessions actually finish, and how many of them ran clean.';
      case PaywallTrigger.settings:
        return 'Unlock every tracker, your full history and the patterns underneath.';
    }
  }
}
