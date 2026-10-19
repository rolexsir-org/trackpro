import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../config/app_environment.dart';
import '../config/pro_config.dart';
import '../main.dart' show TrackTheme;
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../widgets/pro_gate.dart';

/// Opens the paywall. `trigger` is logged with every funnel event, because
/// *where* the paywall appears moves conversion more than its copy does.
Future<bool> showPaywall(BuildContext context, {required PaywallTrigger trigger}) async {
  final state = context.read<AppState>();
  state.analytics?.log('paywall_viewed', {'trigger': trigger.key});
  Haptics.light();

  final result = await Navigator.of(context).push<bool>(
    CupertinoPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(trigger: trigger),
    ),
  );
  if (result != true) {
    state.analytics?.log('paywall_dismissed', {'trigger': trigger.key});
  }
  return result ?? false;
}

/// The paywall.
///
/// Design notes:
/// - **Full screen, not a sheet.** Sheets read as dismissible; a subscription
///   decision needs a considered frame. The blurred backdrop still keeps it in
///   the app's visual language.
/// - **One hero, three plans, one CTA.** No feature comparison matrix — the
///   benefits are written as outcomes ("your full history, forever"), not
///   checkmarks.
/// - **The trial is stated three times**: on the card, in the timeline strip and
///   in the legal line. Ambiguity here is what generates refund requests.
/// - **Restore is always visible** (Play policy requires reachable subscription
///   management, and humans require a way out).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.trigger});

  final PaywallTrigger trigger;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  ProPlan _selected = ProConfig.highlighted;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final billing = context.read<AppState>().billing;
    if (billing != null && billing.plans.isNotEmpty) {
      _selected = billing.plans.firstWhere((p) => p.highlighted, orElse: () => billing.plans.first);
    }
    // Fresh prices on every view: Play localizes offers per country and per
    // cohort, so a cached price can literally be wrong.
    WidgetsBinding.instance.addPostFrameCallback((_) => billing?.loadPlans());
  }

  Future<void> _startPurchase() async {
    final state = context.read<AppState>();
    final billing = state.billing;
    if (billing == null) return;

    setState(() => _busy = true);
    final launched = await billing.buy(_selected);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!launched) {
      final message = billing.lastError;
      if (message != null) {
        showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Could not start the purchase'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // The purchase stream takes over from here: entitlement lands in AppState,
    // and this route pops when the entitlement actually arrives.
    final granted = await _awaitEntitlement(state, const Duration(seconds: 45));
    if (!mounted) return;
    if (granted) {
      Haptics.commit();
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _awaitEntitlement(AppState state, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (state.isPro) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return false;
    }
    return false;
  }

  Future<void> _restore() async {
    final state = context.read<AppState>();
    await state.billing?.restore();
    if (!mounted) return;
    final granted = await _awaitEntitlement(state, const Duration(seconds: 12));
    if (!mounted) return;
    if (granted) {
      Navigator.of(context).pop(true);
    } else {
      showTrackDialog(
        context,
        title: 'Nothing to restore',
        body: 'No active subscription was found for this Google account. If you subscribed with a different account, switch accounts in the Play Store and try again.',
      );
    }
  }

  Future<void> _manage() async {
    final state = context.read<AppState>();
    state.analytics?.log('manage_opened');
    final url = state.billing?.manageUrl(packageName: state.packageName) ??
        'https://play.google.com/store/account/subscriptions';
    if (!await launcher.launchUrl(Uri.parse(url), mode: launcher.LaunchMode.externalApplication)) {
      if (mounted) {
        showTrackDialog(context, title: 'Open Google Play', body: 'Manage or cancel your subscription in Google Play → Subscriptions.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final billing = state.billing;
    final plans = billing?.plans ?? ProConfig.plans;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Deep indigo hero wash: premium without leaving the palette.
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: ProPalette.hero))),
          Positioned(
            top: -140,
            right: -80,
            child: _glowBlob(ProPalette.gold, .22, 320),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _glowBlob(const Color(0xFF7A5CFF), .3, 360),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: () => Navigator.of(context).pop(false), onRestore: _restore),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    children: [
                      // The hero must carry the copy for the placement the user
                      // actually hit — that is the whole reason there are eight.
                      _Hero(trigger: widget.trigger),
                      const SizedBox(height: 20),
                      for (final plan in plans) ...[
                        _PlanCard(
                          plan: plan,
                          selected: plan.id == _selected.id,
                          onTap: () {
                            Haptics.selection();
                            setState(() => _selected = plan);
                            state.analytics?.log('plan_selected', {'plan': plan.id, 'trigger': widget.trigger.key});
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      _Timeline(plan: _selected),
                      const SizedBox(height: 22),
                      const _Benefits(),
                      const SizedBox(height: 22),
                      const _Trust(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
                _Footer(
                  plan: _selected,
                  busy: _busy,
                  available: billing?.available ?? false,
                  onCta: _startPurchase,
                  onManage: _manage,
                  onRestore: _restore,
                  // A purchase Play accepted but the backend has not confirmed is
                  // its own state: the paywall must not keep offering to sell the
                  // same thing, and it must not pretend the purchase failed.
                  confirming: state.purchaseAwaitingVerification,
                  onRecheck: () async {
                    setState(() => _busy = true);
                    await state.recheckPurchase();
                    Haptics.commit();
                    if (mounted) setState(() => _busy = false);
                    if (mounted && !state.isPro) {
                      showTrackDialog(
                        context,
                        title: 'Still confirming',
                        body: state.billing?.lastVerifyOutcome == 'unreachable'
                            ? 'We still cannot reach the verification service. Your purchase is safe in '
                                'Google Play; Pro unlocks as soon as it can be confirmed.'
                            : 'Google Play has not settled this purchase yet. Nothing has been lost — '
                                'tracking stays free in the meantime.',
                      );
                    }
                  },
                  isPro: state.isPro,
                  statusLine: state.entitlement.statusLine,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(Color color, double opacity, double size) => IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.onRestore});

  final VoidCallback onClose;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(34, 34),
            onPressed: onClose,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.14), shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.xmark, size: 16, color: Colors.white),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onRestore,
            child: const Text('Restore', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.trigger});

  final PaywallTrigger trigger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: ProPalette.gradient, borderRadius: BorderRadius.circular(12), boxShadow: ProPalette.glow()),
              child: const Icon(CupertinoIcons.sparkles, size: 20, color: ProPalette.goldText),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Track Pro',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.4, color: Colors.white)),
                Text('One app. Everything. Forever.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xB3FFFFFF))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          trigger.title,
          style: const TextStyle(
            fontSize: 30,
            height: 1.14,
            fontWeight: FontWeight.w700,
            letterSpacing: -.9,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          trigger.body,
          style: const TextStyle(fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w500, color: Color(0xCCFFFFFF)),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  final ProPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subLine = ProConfig.subLineFor(plan);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: TrackTheme.easeOut,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(.16) : Colors.white.withOpacity(.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? ProPalette.gold : Colors.white.withOpacity(.14),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? ProPalette.glow(opacity: .3) : null,
        ),
        child: Row(
          children: [
            // iOS-style radio, not a checkbox.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? ProPalette.gold : Colors.transparent,
                border: Border.all(color: selected ? ProPalette.gold : Colors.white.withOpacity(.4), width: 1.6),
              ),
              child: selected ? const Icon(CupertinoIcons.checkmark_alt, size: 14, color: ProPalette.goldText) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.3, color: Colors.white)),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(gradient: ProPalette.gradient, borderRadius: BorderRadius.circular(6)),
                          child: Text(plan.badge!,
                              style: const TextStyle(
                                  fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .3, color: ProPalette.goldText)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subLine ?? plan.blurb,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xB3FFFFFF)),
                  ),
                  if (plan.hasTrial) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.gift_fill, size: 11, color: ProPalette.gold),
                        const SizedBox(width: 5),
                        Text('${plan.trialDays} days free',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ProPalette.gold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.displayPrice,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5, color: Colors.white)),
                Text(plan.displayPeriod,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0x99FFFFFF))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The trial timeline: the single most effective trust element on a subscription
/// screen, because it answers "when does money leave my account?" before the
/// question is asked.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.plan});

  final ProPlan plan;

  @override
  Widget build(BuildContext context) {
    final steps = plan.hasTrial
        ? const [('Today', 'Full access, no charge'), ('Day 4', 'We remind you'), ('Day 7', 'Your plan starts')]
        : const [('Today', 'Instant access'), ('Renews', 'Cancel anytime'), ('Always', 'Export is free')];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.trialTimeline(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 13),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0 ? ProPalette.gold : Colors.white.withOpacity(.28),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(steps[i].$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(steps[i].$2,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0x99FFFFFF))),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Container(height: 1, color: Colors.white.withOpacity(.16)),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('WHAT PRO ADDS',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: .6, color: Color(0x99FFFFFF))),
        const SizedBox(height: 14),
        for (final b in ProConfig.benefits) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
                child: Text(b.emoji, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(b.body,
                        style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: Color(0xB3FFFFFF))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
        ],
      ],
    );
  }
}

class _Trust extends StatelessWidget {
  const _Trust();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in ProConfig.trustLines)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: Color(0x99FFFFFF)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(line,
                      style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: Color(0xCCFFFFFF))),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.plan,
    required this.busy,
    required this.available,
    required this.onCta,
    required this.onManage,
    required this.onRestore,
    required this.confirming,
    required this.onRecheck,
    required this.isPro,
    required this.statusLine,
  });

  final ProPlan plan;
  final bool busy;
  final bool available;
  final VoidCallback onCta;
  final VoidCallback onManage;
  final VoidCallback onRestore;

  /// True while a completed purchase waits for server-side verification.
  final bool confirming;
  final Future<void> Function() onRecheck;
  final bool isPro;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 14 + bottom),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.3),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
      ),
      child: Column(
        children: [
          if (!available)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Google Play billing is unavailable here — install from the Play Store to subscribe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(.7)),
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: ProPalette.gold),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(statusLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          if (confirming) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.time, size: 14, color: ProPalette.gold),
                const SizedBox(width: 7),
                Flexible(
                  child: Text('Confirming your purchase with Google Play',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(.9))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pro unlocks the moment the payment settles. Nothing is lost if you close this — '
              'the purchase stays attached to your Google account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(.6)),
            ),
            const SizedBox(height: 12),
          ],
          ProCtaButton(
            label: confirming
                ? (busy ? 'Checking…' : 'Check again')
                : (busy ? 'Contacting Google Play…' : plan.ctaFor()),
            loading: busy,
            onTap: busy
                ? null
                : (confirming ? () => onRecheck() : (available ? onCta : null)),
          ),
          const SizedBox(height: 9),
          Text(
            plan.hasTrial
                ? 'Free for ${plan.trialDays} days, then ${plan.displayPrice}${plan.displayPeriod}. '
                    'Auto-renews until cancelled. Cancel anytime in Google Play.'
                : 'One-time payment. No subscription, no renewal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.4, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(.6)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink(label: isPro ? 'Manage subscription' : 'Manage in Google Play', onTap: onManage),
              const SizedBox(width: 14),
              _FooterLink(label: 'Restore', onTap: onRestore),
              const SizedBox(width: 14),
              _FooterLink(label: 'Terms', onTap: () => _openPolicy(context, 'terms')),
              const SizedBox(width: 14),
              _FooterLink(label: 'Privacy', onTap: () => _openPolicy(context, 'privacy')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPolicy(BuildContext context, String which) async {
    final url = which == 'terms' ? AppEnvironment.termsUrl : AppEnvironment.privacyUrl;
    if (url.trim().isNotEmpty) {
      final ok = await launcher.launchUrl(Uri.parse(url.trim()), mode: launcher.LaunchMode.externalApplication);
      if (ok) return;
    }
    if (context.mounted) {
      await showLegalSheet(context, kind: which);
    }
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(.75))),
    );
  }
}

/// Shared alert used by the paywall and Settings.
Future<void> showTrackDialog(BuildContext context, {required String title, required String body}) {
  Haptics.warning();
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(fontSize: 13)),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Bundled Privacy Policy and Terms disclosures, shown when the build has no
/// external URL configured (`TRACK_PRIVACY_URL` / `TRACK_TERMS_URL`) or when the
/// device cannot open a browser. Never invents a URL that does not exist.
Future<void> showLegalSheet(BuildContext context, {required String kind}) {
  final isTerms = kind == 'terms';
  final title = isTerms ? 'Terms & Disclosures' : 'Privacy & Data Flow';
  final sections = isTerms ? _termsSections : _privacySections;
  final configuredUrl = isTerms ? AppEnvironment.termsUrl.trim() : AppEnvironment.privacyUrl.trim();
  final dark = Theme.of(context).brightness == Brightness.dark;

  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: TrackTheme.surface(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TrackTheme.radiusSheet)),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TrackTheme.label3(dark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: TrackTheme.label(dark)),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Done',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TrackTheme.blue),
                    ),
                  ),
                ],
              ),
              Text(
                configuredUrl.isEmpty
                    ? 'In-app disclosure · no external policy URL is configured in this build'
                    : 'Configured URL: $configuredUrl',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final (heading, body) = sections[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: TrackTheme.label2(dark),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const List<(String, String)> _privacySections = <(String, String)>[
  (
    'Local-first storage, no cloud backup',
    'Routines, tracker entries, focus sessions and settings are stored inside the app on this device. '
        'Android backup is turned off, so your health and habit data is never copied to Google Drive '
        'without your explicit action.',
  ),
  (
    'Health Connect (optional, read-only)',
    'When you connect Health Connect in Settings, Track Pro reads Steps, Sleep, and Weight for the last '
        '30 days to fill those trackers. Track Pro never writes to Health Connect, never reads in the '
        'background, and never overwrites a value you typed yourself.',
  ),
  (
    'Android Usage Access & Overlays (optional)',
    'Used only when you enable automatic Screen time or Focus Lock app covering. Only foreground duration '
        'or the active foreground package name is read on-device; no app content, messages, or notifications '
        'are ever read, stored, or transmitted.',
  ),
  (
    'Google Play Billing verification',
    'When you purchase or restore Track Pro, the Google Play purchase token, product ID, and package name '
        '(`com.track.app`) are sent over HTTPS to the verification backend (`TRACK_VERIFY_URL`) solely to '
        'confirm entitlement status with Google Play.',
  ),
  (
    'Export & complete deletion',
    'You can export your recorded history as JSON or CSV, or permanently delete all recorded user data '
        '(trackers, routines, focus sessions, and preferences) at any time from Settings → Your data.',
  ),
];

const List<(String, String)> _termsSections = <(String, String)>[
  (
    'Subscriptions & renewals',
    'Track Pro subscriptions (`track_pro_monthly`, `track_pro_annual`) are billed through Google Play and '
        'renew automatically unless cancelled at least 24 hours before the current period ends. You can '
        'manage or cancel at any time in Google Play → Payments & subscriptions → Subscriptions.',
  ),
  (
    'Free trials & lifetime access',
    'Where a 7-day free trial is offered on the annual plan, unused trial time converts to an auto-renewing '
        'annual subscription unless cancelled in Google Play before the trial ends. The lifetime plan is a '
        'one-time non-consumable purchase.',
  ),
  (
    'Informational use, not medical advice',
    'All measurements, sleep and weight trends, and cycle predictions are informational summaries computed '
        'from the numbers you log or sync. Track Pro is not a medical device and does not provide medical '
        'advice, diagnosis, or contraception.',
  ),
  (
    'Focus Lock best-effort disclosure',
    'Android does not let an ordinary app stop another app from launching. Focus Lock covers selected '
        'apps on a best-effort basis using the permissions you grant, and never covers the phone dialer, '
        'emergency call screens, or system settings.',
  ),
];

/// Convenience: the soft prompt.
///
/// Fired when the user is genuinely getting value — a streak they would hate to
/// break, or a tracker ceiling they just hit. Never on launch, never twice in a
/// row: a paywall that interrupts the habit loop costs more in retention than it
/// earns in revenue.
Future<void> maybeShowSoftPrompt(BuildContext context, AppState state) async {
  if (state.isPro) return;
  final lastShown = state.softPromptLastShown;
  if (lastShown != null && DateTime.now().difference(lastShown).inDays < 14) return;

  final streak = state.streak('habits');
  final atLimit = state.visibleTrackers.length >= ProConfig.freeTrackerLimit;
  if (streak < 7 && !atLimit) return;

  state.analytics?.log('soft_prompt_shown', {'streak': streak, 'at_limit': atLimit});
  state.markSoftPromptShown();
  await showPaywall(context, trigger: PaywallTrigger.softPrompt);
}
