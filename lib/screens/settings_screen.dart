import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../services/haptics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_environment.dart';
import '../config/pro_config.dart';
import '../main.dart' show TrackTheme;
import '../services/health_service.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import '../widgets/pro_gate.dart';
import 'focus_history_screen.dart';
import 'focus_profiles_screen.dart';
import 'focus_setup_sheets.dart';
import 'log_sheets.dart';
import 'measurements_page.dart';
import 'paywall_screen.dart';

/// Settings: goal customisation, appearance, notifications, data ownership.
/// Showing people their own accumulated data is the strongest retention cue in
/// the whole app — so it gets a dedicated section.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        const LargeTitleHeader(title: 'Profile', subtitle: 'Your settings and data'),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProfileCard(state: state),
              const SectionLabel('Routines'),
              GlassList(
                children: [
                  GlassRow(
                    title: 'Routines',
                    subtitle: state.hasCommitments
                        ? '${state.commitments.length} active'
                              '${state.archivedCommitments.isEmpty ? '' : ' · ${state.archivedCommitments.length} archived'}'
                              ' · ${state.overallMomentum?.rate == null ? 'gathering evidence' : '${state.overallMomentum!.rate!.round()}% momentum'}'
                        : 'None yet — the habit engine starts empty',
                    leading: const Icon(Icons.repeat_rounded, size: 18, color: TrackTheme.orange),
                    accent: TrackTheme.green,
                    onTap: () => state.setTab(1),
                  ),
                ],
              ),
              const SectionLabel('Trackers'),
              GlassList(
                children: [
                  GlassRow(
                    title: 'All trackers',
                    subtitle: 'Measurements, reorder, hide or add',
                    leading: const Icon(Icons.tune_rounded, size: 18, color: TrackTheme.orange),
                    trailing: Text(
                      '${state.visibleTrackers.length} active',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
                    ),
                    // One destination, one row: this used to be two rows ("Measurements"
                    // here and "Manage trackers" below) that pushed the same screen. The
                    // trackers screen is a pushed page — deliberately not a tab — so the
                    // row pushes it, and `setTab(2)` (Momentum) is no longer where a
                    // promise about trackers goes.
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MeasurementsPage())),
                  ),
                  for (final t in state.trackers.take(4))
                    GlassRow(
                      title: '${t.name} goal',
                      leading: Icon(Icons.flag_outlined, size: 18, color: t.accent),
                      accent: t.accent,
                      trailing: Text(
                        fmtGoalLong(t),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
                      ),
                      onTap: () => openGoalSheet(context, t),
                    ),
                ],
              ),
              const SectionLabel('Appearance'),
              GlassList(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -.32,
                                color: TrackTheme.label(dark),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Light surfaces or true-black dark',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: TrackTheme.fill(dark),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              for (final o in const [
                                ['Light', false],
                                ['Dark', true],
                              ])
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => state.setTheme(o[1] as bool),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(vertical: 7),
                                      decoration: BoxDecoration(
                                        color: state.isDark == o[1] ? TrackTheme.surface(dark) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: state.isDark == o[1]
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: .12),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        o[0] as String,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: TrackTheme.label(dark),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SectionLabel('Feedback'),
              GlassList(children: [_HapticRow()]),
              const SectionLabel('Notifications'),
              GlassList(
                children: [
                  // Every switch below is persisted and re-schedules the real
                  // notification. They used to be local widget booleans: they
                  // flipped, they looked convincing, and they controlled nothing.
                  _NotifyRow(
                    title: 'Daily check-in',
                    subtitle:
                        'Free · around 9:00 pm. Reminders are scheduled inexactly, so '
                        'Android may deliver them a few minutes late — never early.',
                    value: state.notifyDaily,
                    onChanged: state.setNotifyDaily,
                  ),
                  _NotifyRow(
                    title: 'Show details on the lock screen',
                    subtitle: 'Off: reminders say how many trackers are open, not which',
                    value: state.lockScreenDetails,
                    onChanged: state.setLockScreenDetails,
                  ),
                  if (state.isPro) ...[
                    _NotifyRow(
                      title: 'Streak saver',
                      subtitle: 'Only when a streak is about to break',
                      value: state.notifyStreakSaver,
                      onChanged: state.setNotifyStreakSaver,
                    ),
                    _NotifyRow(
                      title: 'Weekly report',
                      subtitle: 'Sunday recap with trends',
                      value: state.notifyWeekly,
                      onChanged: state.setNotifyWeekly,
                    ),
                  ] else
                    ProLockedRow(
                      title: 'Streak saver + weekly report',
                      subtitle: 'Rescue a streak before it breaks · Pro',
                      emoji: 'streak',
                      accent: TrackTheme.orange,
                      onTap: () {
                        state.analytics?.log('pro_gate_tapped', {'gate': 'notifications'});
                        showPaywall(context, trigger: PaywallTrigger.streakSave);
                      },
                    ),
                  if (!state.notificationsAllowed)
                    GlassRow(
                      title: 'Notifications are off',
                      subtitle: 'Android is blocking them, so none of the above can arrive',
                      leading: const Icon(Icons.notifications_off_outlined, size: 18, color: TrackTheme.orange),
                      accent: TrackTheme.orange,
                      trailing: Text(
                        'Turn on',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.blue),
                      ),
                      onTap: () async {
                        // The system prompt is a bare switch. This sheet is the sentence
                        // before it: what will be sent, and what is never sent.
                        final explained = await _explainPermission(
                          context,
                          title: 'Allow notifications?',
                          body:
                              'Track Pro uses them for the daily check-in, a streak reminder and the '
                              'running focus notice. They are built on this device and never include '
                              'what you typed in a note.',
                          confirm: 'Continue',
                        );
                        if (!explained || !context.mounted) return;
                        final ok = await state.notifications?.requestPermission() ?? false;
                        if (!context.mounted) return;
                        if (ok) {
                          await state.refreshReminders();
                        } else if (context.mounted) {
                          showTrackDialog(
                            context,
                            title: 'Turn notifications on',
                            body:
                                'Android only offers the prompt once. If nothing appeared, open '
                                'Settings → Apps → Track Pro → Notifications and allow them, then come back.',
                          );
                        }
                      },
                    ),
                ],
              ),
              const SectionLabel('Focus Lock'),
              GlassList(
                children: [
                  // One row that states the current enforcement capability, not the
                  // configured one. Tapping it opens the same permission explainer the
                  // session sheet uses, so the wording can never drift between the two.
                  GlassRow(
                    title: 'App covering',
                    subtitle: state.focusPermissions.canBlock
                        ? 'Ready to request app coverage'
                        : 'Needs ${state.focusPermissions.missingForBlockingLabel}',
                    leading: Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: state.focusPermissions.canBlock ? TrackTheme.green : TrackTheme.orange,
                    ),
                    accent: state.focusPermissions.canBlock ? TrackTheme.green : TrackTheme.orange,
                    trailing: state.focusPermissions.canBlock
                        ? null
                        : Text(
                            'Set up',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.blue),
                          ),
                    onTap: () => openFocusPermissionSheet(context),
                  ),
                  GlassRow(
                    title: 'Focus history',
                    subtitle: state.focusStats.endedSessions == 0
                        ? 'No sessions recorded yet'
                        : '${state.focusStats.endedSessions} session'
                              '${state.focusStats.endedSessions == 1 ? '' : 's'} · '
                              '${state.focusStats.minutesLast7Days} min in the last 7 days',
                    leading: const Icon(Icons.history_rounded, size: 18, color: TrackTheme.orange),
                    accent: TrackTheme.indigo,
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FocusHistoryScreen())),
                  ),
                  if (state.canUseFocusProfiles || state.canUseFocusSchedules)
                    GlassRow(
                      title: 'Profiles & schedules',
                      subtitle: 'Reusable rule sets, and reminders for deep focus',
                      leading: const Icon(Icons.schedule_outlined, size: 18, color: TrackTheme.orange),
                      accent: TrackTheme.purple,
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => const FocusProfilesScreen())),
                    )
                  else
                    ProLockedRow(
                      title: 'Profiles & schedules',
                      subtitle: 'One-tap sessions, and deep focus at a time you choose. Every mode stays free.',
                      emoji: 'settings',
                      accent: TrackTheme.purple,
                      onTap: () {
                        state.analytics?.log('pro_gate_tapped', {'gate': 'focus_profiles'});
                        showPaywall(context, trigger: PaywallTrigger.focusProfiles);
                      },
                    ),
                ],
              ),
              const SectionLabel('Data'),
              GlassList(
                children: [
                  GlassRow(
                    title: 'Export data',
                    subtitle: state.entryCount == 0
                        ? 'Nothing to export yet'
                        : 'JSON or CSV · ${state.entryCount} ${state.entryCount == 1 ? 'entry' : 'entries'}',
                    leading: const Icon(Icons.file_upload_outlined, size: 18, color: TrackTheme.orange),
                    accent: TrackTheme.green,
                    trailing: Text(
                      'Export',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.blue),
                    ),
                    onTap: () => _showExport(context, state),
                  ),
                  if (!state.canUseHealthSync)
                    ProLockedRow(
                      title: 'Health Connect sync',
                      subtitle: 'Steps, sleep and weight filled in for you — Pro',
                      emoji: 'health',
                      accent: TrackTheme.green,
                      onTap: () {
                        state.analytics?.log('pro_gate_tapped', {'gate': 'health_sync'});
                        showPaywall(context, trigger: PaywallTrigger.healthSync);
                      },
                    )
                  else
                    GlassRow(
                      title: 'Health Connect',
                      // Four different answers, because they need four different actions:
                      // install it, grant it, ask again, or sync. Reporting all of them as
                      // "not connected" told the user nothing they could act on, and claiming
                      // "connected" from a remembered value kept saying it after a revocation.
                      subtitle: switch (state.healthPermission) {
                        HealthPermissionState.granted =>
                          state.lastSync == null
                              ? 'Connected · nothing synced yet'
                              : 'Connected · last sync ${shortDate(state.lastSync!)} · '
                                    '${state.healthSyncedDays} days merged',
                        HealthPermissionState.denied => 'Permission not granted — steps, sleep and weight stay manual',
                        HealthPermissionState.unavailable => 'Health Connect is not installed on this device',
                        HealthPermissionState.unknown => 'Not checked yet this session',
                      },
                      leading: const Icon(Icons.favorite_border_rounded, size: 18, color: TrackTheme.orange),
                      accent: TrackTheme.pink,
                      trailing: Text(
                        state.healthPermission == HealthPermissionState.granted ? 'Sync now' : 'Connect',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.blue),
                      ),
                      onTap: () async {
                        if (!state.healthConnected) {
                          final explained = await _explainPermission(
                            context,
                            title: 'Connect Health Connect?',
                            body:
                                'Track Pro reads steps, sleep and weight so those trackers can fill '
                                'themselves in. It never writes to Health Connect, and nothing leaves '
                                'this device.',
                            confirm: 'Continue',
                          );
                          if (!explained || !context.mounted) return;
                        }
                        final result = await state.syncHealth(askPermission: true);
                        if (!context.mounted) return;
                        switch (result) {
                          case -2:
                            // Pro feature, and said so instead of blaming a permission the
                            // user may well have granted.
                            showTrackToast(context, 'Health sync is part of Pro — nothing was read');
                            showPaywall(context, trigger: PaywallTrigger.healthSync);
                          case -1:
                            showTrackToast(context, 'Health Connect permission was not granted');
                          case 0:
                            showTrackToast(
                              context,
                              state.healthPermission == HealthPermissionState.unavailable
                                  ? 'Health Connect is not available on this device'
                                  : state.healthPermission == HealthPermissionState.granted
                                  ? 'Connected — nothing new to merge'
                                  : 'Permission not granted, so nothing was read',
                            );
                          default:
                            showTrackToast(
                              context,
                              'Synced $result ${result == 1 ? 'day' : 'days'} — steps, sleep, weight',
                            );
                        }
                      },
                    ),
                  GlassRow(
                    // Was "Cloud backup — last sync: today, 6:02 am" with a switch
                    // that was always on. There is no cloud service: the app has
                    // never had one, and claiming otherwise invents both a feature
                    // and a timestamp. This row says what is actually true, and
                    // Export (above) is the real way to keep a copy.
                    title: 'Where your data lives',
                    subtitle: 'On this device only · ${state.entryCount} entries · export to keep a copy',
                    leading: const Icon(Icons.phone_android_outlined, size: 18, color: TrackTheme.orange),
                    accent: TrackTheme.indigo,
                    showChevron: false,
                    trailing: const Text('Local', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  GlassRow(
                    title: 'Recalculate insights',
                    subtitle: 'Rebuild patterns from all history',
                    leading: const Icon(Icons.refresh_rounded, size: 18, color: TrackTheme.orange),
                    accent: TrackTheme.orange,
                    trailing: Text(
                      'Run',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
                    ),
                    onTap: () async {
                      // Was a toast reading "Rebuilding from 1,284 entries…" — a
                      // fabricated count over an action that did nothing. It now runs
                      // the real aggregation and reports the real number of rows.
                      final count = state.entryCount;
                      if (count == 0) {
                        showTrackToast(context, 'Nothing to rebuild yet — log something first');
                        return;
                      }
                      showTrackToast(context, 'Rebuilding from $count ${count == 1 ? 'entry' : 'entries'}…');
                      await state.refreshInsights();
                      if (context.mounted) {
                        // `insights` holds the pattern statements that survived the
                        // sample-size thresholds; there is no separate collection.
                        final patterns = state.insights.length;
                        showTrackToast(
                          context,
                          patterns == 0
                              ? 'Rebuilt from $count entries · more days needed for patterns'
                              : 'Rebuilt from $count entries · $patterns patterns',
                        );
                      }
                    },
                  ),
                  if (state.demoRowCount > 0)
                    GlassRow(
                      title: 'Remove sample data',
                      subtitle: 'Deletes the ${state.demoRowCount} seeded rows, keeps everything you logged',
                      leading: const Icon(Icons.science_outlined, size: 18, color: TrackTheme.orange),
                      accent: TrackTheme.orange,
                      showChevron: false,
                      trailing: Text(
                        'Remove',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.orange),
                      ),
                      onTap: () async {
                        await state.removeSampleData();
                        if (context.mounted) showTrackToast(context, 'Sample data removed');
                      },
                    ),
                  GlassRow(
                    // Was "Reset demo data → 28 days restored": a reset that recreated
                    // synthetic history. Deleting is now the only behaviour, and the
                    // empty state that follows is honest about being empty.
                    title: 'Delete all data',
                    subtitle: 'Erases your entries, routines and focus sessions. Nothing is recreated.',
                    leading: const Icon(Icons.delete_outline_rounded, size: 18, color: TrackTheme.red),
                    accent: TrackTheme.red,
                    showChevron: false,
                    trailing: Text(
                      'Delete',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.red),
                    ),
                    onTap: () async {
                      final confirmed = await showTrackConfirm(
                        context,
                        title: 'Delete all data?',
                        body:
                            'Removed: your ${state.entryCount} entries and their history, your '
                            '${state.commitments.length} routine${state.commitments.length == 1 ? '' : 's'} with '
                            'every day recorded against them, and every focus session and saved focus rule on '
                            'this device. Kept: your trackers and goals, and your settings. '
                            'Export first if you want a copy — this cannot be undone.',
                        confirmLabel: 'Delete everything',
                      );
                      if (!confirmed) return;
                      final removed = await state.reset();
                      if (context.mounted) {
                        // The counts are the ones SQLite just reported, not the ones the
                        // dialog predicted — if the two ever disagree, the user sees the
                        // real number.
                        showTrackToast(
                          context,
                          'Deleted ${removed['daily_entries'] ?? 0} daily rows, '
                          '${removed['routines'] ?? 0} routine${(removed['routines'] ?? 0) == 1 ? '' : 's'} and '
                          '${removed['focus_sessions'] ?? 0} focus sessions',
                        );
                      }
                    },
                  ),
                ],
              ),
              // Storage health, in the only two states a person can act on. The
              // SQL counts, migration bookkeeping and build flags that used to live
              // here were for whoever was debugging this build, not for the person
              // using it; the one thing worth surfacing is a save that did not land.
              if (!state.integrityOk || state.writeFailure != null) ...[
                const SectionLabel('Storage'),
                GlassList(
                  children: [
                    if (!state.integrityOk)
                      GlassRow(
                        title: 'Storage needs attention',
                        subtitle: 'Export a copy of your data, then reinstall if problems continue.',
                        leading: const Icon(Icons.warning_amber_rounded, size: 18, color: TrackTheme.orange),
                        accent: TrackTheme.orange,
                        showChevron: false,
                      ),
                    if (state.writeFailure != null)
                      GlassRow(
                        title: 'Last save problem',
                        subtitle:
                            '${state.writeFailure!.action} was not saved. '
                            'Your previous value is unchanged.',
                        leading: const Icon(Icons.warning_amber_rounded, size: 18, color: TrackTheme.orange),
                        accent: TrackTheme.orange,
                        showChevron: false,
                      ),
                  ],
                ),
              ],
              const SectionLabel('Premium'),
              _ProSection(state: state),
              const SectionLabel('Help & support'),
              GlassList(
                children: [
                  GlassRow(
                    title: 'Manage subscription',
                    subtitle: state.isPro ? 'Cancel or change plan in Google Play' : 'Nothing to manage yet',
                    leading: const Icon(Icons.credit_card_outlined, size: 18, color: TrackTheme.orange),
                    onTap: () async {
                      final url = state.billing?.manageUrl(packageName: state.packageName);
                      state.analytics?.log('manage_opened');
                      if (url != null) await launchManage(context, url);
                    },
                  ),
                  GlassRow(
                    title: 'Restore purchases',
                    subtitle: 'Already subscribed on another install?',
                    leading: const Icon(Icons.restore_rounded, size: 18, color: TrackTheme.orange),
                    onTap: () => restoreFromSettings(context, state),
                  ),
                  GlassRow(
                    title: 'Rate Track Pro',
                    subtitle: 'Helps other people find it',
                    leading: const Icon(Icons.star_outline_rounded, size: 18, color: TrackTheme.orange),
                    onTap: () => launchPlayListing(context, state.packageName),
                  ),
                ],
              ),
              const SectionLabel('Privacy & security'),
              GlassList(
                children: [
                  GlassRow(
                    title: 'Privacy',
                    subtitle: AppEnvironment.hasHostedPolicies
                        ? 'How your data is stored and handled'
                        : 'In-app summary · no external URL configured in this build',
                    leading: const Icon(Icons.lock_outline_rounded, size: 18, color: TrackTheme.orange),
                    accent: const Color(0xFF8E8E93),
                    onTap: () => openPolicy(context, AppEnvironment.privacyUrl, 'Privacy policy'),
                  ),
                  GlassRow(
                    title: 'Terms & disclosures',
                    subtitle: AppEnvironment.hasHostedPolicies
                        ? 'Subscription terms and product disclosures'
                        : 'In-app summary · no external URL configured in this build',
                    leading: const Icon(Icons.description_outlined, size: 18, color: TrackTheme.orange),
                    accent: const Color(0xFF8E8E93),
                    onTap: () => openPolicy(context, AppEnvironment.termsUrl, 'Terms of service'),
                  ),
                  GlassRow(
                    title: 'Version',
                    leading: const Icon(Icons.info_outline_rounded, size: 18, color: TrackTheme.orange),
                    accent: const Color(0xFF8E8E93),
                    showChevron: false,
                    trailing: const _VersionTrailing(),
                  ),
                ],
              ),
              if (kDebugMode) ...[
                const SectionLabel('Developer options'),
                GlassList(
                  children: [
                    GlassRow(
                      title: 'Refresh device state',
                      subtitle: 'Re-check Focus and Health permissions without changing them',
                      leading: const Icon(Icons.refresh_rounded, size: 18, color: TrackTheme.orange),
                      onTap: () async {
                        await state.refreshFocusPermissions();
                        await state.refreshHealthPermission();
                        if (context.mounted) showTrackToast(context, 'Device state refreshed');
                      },
                    ),
                    GlassRow(
                      title: 'Build configuration',
                      subtitle: 'Show release configuration checks for this debug build',
                      leading: const Icon(Icons.bug_report_outlined, size: 18, color: TrackTheme.orange),
                      onTap: () {
                        final problems = AppEnvironment.validate();
                        showTrackDialog(
                          context,
                          title: 'Build configuration',
                          body: problems.isEmpty ? 'No configuration problems reported.' : problems.join('\n\n'),
                        );
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Track Pro · everything stays on this device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                  color: TrackTheme.label3(dark),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// The account surface for Pro. Deliberately not a second paywall: it states the
/// tier, the renewal reality and how to leave, in one place the Play Store can
/// point reviewers at.
/// "We have your purchase, Google has not confirmed it yet."
///
/// Deliberately not a paywall and not a success screen: it states what is true,
/// keeps the free tier working, and gives the user the two actions that can
/// actually change the outcome (retry, restore).
class _ConfirmingCard extends StatefulWidget {
  const _ConfirmingCard({required this.state});

  final AppState state;

  @override
  State<_ConfirmingCard> createState() => _ConfirmingCardState();
}

class _ConfirmingCardState extends State<_ConfirmingCard> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    await widget.state.recheckPurchase();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.state;
    final outcome = state.billing?.lastVerifyOutcome;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: ProPalette.gold.withValues(alpha: dark ? .3 : .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 18, color: ProPalette.goldDeep),
              const SizedBox(width: 8),
              Text(
                'Confirming with Google Play',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                  color: TrackTheme.label(dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            // Honest about the state of the world, and about what Pro needs.
            outcome == 'unreachable'
                ? 'We could not reach the verification service, so Pro has not been unlocked yet. '
                      'Your purchase is safe in Google Play — nothing has been charged twice and nothing is lost. '
                      'This will retry by itself when you have a connection.'
                : 'Google Play has your purchase and we are waiting for it to settle. Pro unlocks the '
                      'moment the payment clears — every tracker works on the free plan in the meantime.',
            style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProOutlineButton(
                  label: _checking ? 'Checking…' : 'Check again',
                  onTap: _checking ? () {} : _check,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProOutlineButton(label: 'Restore', onTap: () => restoreFromSettings(context, state)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProSection extends StatelessWidget {
  const _ProSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ent = state.entitlement;

    // A purchase Play accepted but the backend has not confirmed yet. This state
    // used to be invisible: the app granted Pro optimistically and printed
    // "Confirming…" underneath. Pro is now withheld until verification lands, so
    // the state needs to be something the user can see, understand and retry.
    if (state.purchaseAwaitingVerification) {
      return _ConfirmingCard(state: state);
    }

    if (!state.isPro) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: BoxDecoration(
          color: ProPalette.surface,
          borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
          border: Border.all(color: ProPalette.gold.withValues(alpha: .55), width: .5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 18, color: ProPalette.gold),
                const SizedBox(width: 8),
                Text(
                  'Pro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: TrackTheme.label(dark),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ProPalette.gold, borderRadius: BorderRadius.circular(7)),
                  child: Text(
                    state.visibleTrackers.length >= ProConfig.freeTrackerLimit
                        ? 'LIMIT REACHED'
                        : '${ProConfig.trialDays} DAYS FREE',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: ProPalette.goldText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Every tracker, your whole history, and the patterns that need both.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: TrackTheme.label2(dark),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  // ProCtaButton, not the private _ProButton: same widget, but
                  // this one is visible outside pro_gate.dart.
                  child: ProCtaButton(
                    label: 'Start ${ProConfig.trialDays}-day free trial',
                    onTap: () {
                      state.analytics?.log('pro_gate_tapped', {'gate': 'settings'});
                      showPaywall(context, trigger: PaywallTrigger.settings);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Free plan: ${ProConfig.freeTrackerLimit} trackers · ${ProConfig.freeHistoryDays} days of history. '
              'Everything you have already logged stays yours.',
              style: TextStyle(fontSize: 11, height: 1.35, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
            ),
          ],
        ),
      );
    }

    final renew = ent.autoRenew
        ? (ent.expiresAt == null ? 'Renews automatically' : 'Renews ${shortDate(ent.expiresAt!)}')
        : 'Cancelled · access until ${ent.expiresAt == null ? '—' : shortDate(ent.expiresAt!)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: ProPalette.gold.withValues(alpha: dark ? .3 : .45), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 18, color: ProPalette.goldDeep),
              const SizedBox(width: 8),
              Text(
                ent.planTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                  color: TrackTheme.label(dark),
                ),
              ),
              const Spacer(),
              const ProChip(compact: true, label: 'ACTIVE'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            renew,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
          ),
          if (ent.inTrial) ...[
            const SizedBox(height: 4),
            Text(
              '${ent.trialDaysLeft} days of free trial left — cancel anytime and pay nothing.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
            ),
          ],
          // No "unverified but active" case exists any more: an unverified claim
          // cannot be active (`Entitlement.active`), so it is rendered above by
          // the confirming card instead. Pro here is always server-verified.
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProOutlineButton(
                  label: 'Manage',
                  onTap: () async {
                    state.analytics?.log('manage_opened');
                    final url = state.billing?.manageUrl(packageName: state.packageName);
                    if (url != null) await launchManage(context, url);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProOutlineButton(label: 'Restore', onTap: () => restoreFromSettings(context, state)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProOutlineButton extends StatelessWidget {
  const _ProOutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: .07) : Colors.black.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
        ),
      ),
    );
  }
}

/// Restore from Settings: same path the paywall uses, but with a plain result.
Future<void> restoreFromSettings(BuildContext context, AppState state) async {
  state.analytics?.log('restore_started');
  final before = state.isPro;
  await state.billing?.restore();
  await Future<void>.delayed(const Duration(seconds: 4));
  if (!context.mounted) return;
  if (state.isPro && !before) {
    showTrackDialog(context, title: 'Welcome back', body: 'Pro restored. Everything is unlocked.');
  } else if (!state.isPro) {
    showTrackDialog(
      context,
      title: 'Nothing to restore',
      body:
          'No active subscription is linked to this Google account. Subscribed with a different account? Switch in the Play Store and try again.',
    );
  }
}

/// Confirmation sheet for irreversible actions. Returns false when dismissed.
Future<bool> showTrackConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: TrackTheme.surface(dark),
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: TextStyle(color: TrackTheme.label(dark))),
      content: SingleChildScrollView(
        child: Text(body, style: TextStyle(color: TrackTheme.label2(dark), height: 1.4)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TrackTheme.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Opens an external page when configured, or the bundled in-app disclosure
/// sheet when the build has no URL configured — never a fabricated URL.
Future<void> openPolicy(BuildContext context, String url, String label) async {
  final kind = label.toLowerCase().contains('term') ? 'terms' : 'privacy';
  if (url.trim().isEmpty) {
    await showLegalSheet(context, kind: kind);
    return;
  }
  final ok = await launcher.launchUrl(Uri.parse(url.trim()), mode: launcher.LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    await showLegalSheet(context, kind: kind);
  }
}

/// The Play listing for a package id.
Future<void> launchPlayListing(BuildContext context, String packageName) async {
  final url = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
  final ok = await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showTrackDialog(context, title: 'Rate Track Pro', body: 'Could not open the Play Store on this device.');
  }
}

Future<void> launchManage(BuildContext context, String? url) async {
  final target = url ?? 'https://play.google.com/store/account/subscriptions';
  final ok = await launcher.launchUrl(Uri.parse(target), mode: launcher.LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showTrackDialog(
      context,
      title: 'Open Google Play',
      body: 'Find Track Pro under Play Store → Payments & subscriptions → Subscriptions.',
    );
  }
}

/// Version + build number from the installed package. Shown as an em dash rather
/// than a hardcoded "1.0.0 (12)" if the platform cannot report it.
class _VersionTrailing extends StatelessWidget {
  const _VersionTrailing();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark));
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return Text('—', style: style);
        final build = info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})';
        return Text('${info.version}$build', style: style);
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        border: Border.all(color: TrackTheme.separator(dark), width: .5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TrackTheme.fill(dark),
              border: Border.all(color: TrackTheme.separator(dark), width: .5),
            ),
            // There is no account profile, so this remains a neutral device mark.
            child: const Icon(Icons.person_outline_rounded, size: 26, color: TrackTheme.orange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // No name, because there is no account: this card used to read
                // "Jai Deshmukh", an invented user shown to everybody. What is left
                // is the truth — how long this install has been logging, and how
                // many routines or trackers are running.
                Text(
                  'This device',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.35,
                    color: TrackTheme.label(dark),
                  ),
                ),
                Text(
                  state.trackingSince == null
                      ? (state.hasCommitments
                            ? '${state.commitments.length} routine${state.commitments.length == 1 ? '' : 's'} · no days logged yet'
                            : 'Nothing logged yet · ${state.visibleTrackers.length} trackers ready')
                      : 'Tracking since ${shortDate(state.trackingSince!)} · '
                            '${state.hasCommitments ? '${state.commitments.length} routines' : '${state.visibleTrackers.length} trackers'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                ),
                const SizedBox(height: 6),
                // The badge used to be unconditional: every free user was shown a
                // "TRACK PRO" chip they had not bought.
                if (state.isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: ProPalette.gold, borderRadius: BorderRadius.circular(7)),
                    child: const Text(
                      'TRACK PRO',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .3,
                        color: ProPalette.goldText,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(7)),
                    // Shown only in the non-Pro branch above, so this cannot claim a
                    // tier the entitlement does not hold.
                    child: Text(
                      'Free plan',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                        color: TrackTheme.label2(dark),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: TrackTheme.label3(dark)),
        ],
      ),
    );
  }
}

/// A settings switch that reflects persisted state and mutates it.
///
/// The value comes from `AppState` and the tap writes back through it, so the
/// switch, the schedule and the database cannot disagree — including after a
/// restart, which is exactly where the previous widget-local version failed.
class _NotifyRow extends StatelessWidget {
  const _NotifyRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.selection();
        // Fire-and-forget through the real setter. The switch re-renders from
        // AppState, so what you see is what was persisted — no local drift.
        unawaited(onChanged(!value));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.notifications_outlined, size: 17, color: TrackTheme.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.32,
                      color: TrackTheme.label(dark),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: TrackTheme.easeOut,
              width: 51,
              height: 31,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? TrackTheme.green : TrackTheme.fill(dark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: TrackTheme.spring,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showExport(BuildContext context, AppState state) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  // Export is a SQL query over the entries tables — no reconstruction, no
  // pagination, and it works with 5 years of history as fast as 5 weeks.
  final json = await state.exportJson();
  await showGlassSheet<void>(
    context,
    title: 'Export data',
    subtitle: 'JSON · ${state.entryCount} ${state.entryCount == 1 ? 'entry' : 'entries'} · on-device by default',
    accent: TrackTheme.green,
    body: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(12)),
      child: Text(
        json.length > 1400 ? '${json.substring(0, 1400)}…' : json,
        style: TextStyle(fontSize: 11.5, height: 1.45, fontFamily: 'monospace', color: TrackTheme.label2(dark)),
      ),
    ),
    actions: [
      TrackFilledButton(
        label: 'Copy JSON',
        color: TrackTheme.green,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: json));
          if (context.mounted) {
            Navigator.of(context).pop();
            showTrackToast(context, 'JSON copied to clipboard');
          }
        },
      ),
      TrackTintedButton(
        label: 'Copy CSV',
        onTap: () async {
          final csv = await state.exportCsv();
          await Clipboard.setData(ClipboardData(text: csv));
          if (context.mounted) {
            Navigator.of(context).pop();
            showTrackToast(context, 'CSV copied · paste into Sheets');
          }
        },
      ),
      // The routines live in a second table; without this the file a user takes
      // away would silently leave out everything they logged against a commitment.
      if (state.hasCommitments)
        TrackTintedButton(
          label: 'Copy routines CSV',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: state.exportCommitmentsCsv()));
            if (context.mounted) {
              Navigator.of(context).pop();
              showTrackToast(context, 'Routine days copied');
            }
          },
        ),
      TrackTintedButton(label: 'Close', onTap: () => Navigator.of(context).pop()),
    ],
  );
}

/// Haptics toggle — a real accessibility affordance, not decoration.
class _HapticRow extends StatefulWidget {
  const _HapticRow();

  @override
  State<_HapticRow> createState() => _HapticRowState();
}

class _HapticRowState extends State<_HapticRow> {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final on = Haptics.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          Haptics.enabled = !on;
        });
        // Only one haptic fires here: the "on" confirmation. Turning it off is
        // silent, because buzzing to say "haptics are off" is absurd.
        if (Haptics.enabled) Haptics.selection();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.vibration_rounded, size: 18, color: TrackTheme.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Haptics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.32,
                      color: TrackTheme.label(dark),
                    ),
                  ),
                  Text(
                    'Crisp ticks on every tap, log and streak save',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: TrackTheme.easeOut,
              width: 51,
              height: 31,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: on ? TrackTheme.green : TrackTheme.fill(dark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: TrackTheme.spring,
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One short explanation before a system permission prompt.
///
/// Android's own dialogs are a single line and arrive without context; Play's policy
/// asks for an in-app rationale before the prompt. This is that rationale — two
/// sentences, with a way out — and it never asks on the app's behalf without the
/// person tapping through it.
Future<bool> _explainPermission(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
}) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final answer = await showGlassSheet<bool>(
    context,
    title: title,
    accent: TrackTheme.blue,
    body: Text(
      body,
      style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
    ),
    // One responsive action row keeps this short rationale readable without
    // turning two small choices into a needlessly tall, scrollable sheet. The
    // shared buttons grow vertically at larger Android font scales if needed.
    actions: [
      Row(
        children: [
          Expanded(
            child: TrackTintedButton(label: 'Not now', onTap: () => Navigator.of(context).pop(false)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TrackFilledButton(label: confirm, onTap: () => Navigator.of(context).pop(true)),
          ),
        ],
      ),
    ],
  );
  return answer ?? false;
}
