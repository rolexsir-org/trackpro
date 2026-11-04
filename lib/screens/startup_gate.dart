import 'dart:async';

import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../main.dart' show TrackTheme;
import '../state/app_startup.dart';
import '../widgets/glass.dart';
import 'home_shell.dart';

/// The first widget the app builds, and the only one that decides whether the real
/// interface may exist yet.
///
/// This replaces `home: const HomeShell()` in `TrackApp`. The difference is not cosmetic:
/// `HomeShell` renders data, and before this gate nothing checked whether the data was
/// there. `main()` simply awaited every initialization step and then called `runApp`, so
/// the app had exactly two possible outcomes — every screen, or no frame at all. A failed
/// or wedged initialization produced the second one, which is the blank screen: the
/// launcher's splash colour, indefinitely, with no message, no retry, and (in release,
/// where `debugPrint` only reaches logcat) no record.
///
/// With the gate, "starting" is a screen the user can read, and "failed" is a screen with
/// the actual reason and a Retry button. The real interface is only mounted once
/// the state reports `isLoaded` — see [AppStartup] rule 1.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.startup});

  final AppStartup startup;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  @override
  void initState() {
    super.initState();
    // A microtask rather than a direct call: `start()` notifies listeners immediately, and
    // notifying during the first build is a `setState() called during build` error. The
    // microtask runs once the frame's synchronous work has finished, which also means the
    // start-up screen is painted before any I/O begins.
    unawaited(Future<void>.microtask(_start));
  }

  Future<void> _start() => widget.startup.start();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.startup,
      builder: (context, _) {
        final phase = widget.startup.phase;
        if (phase == StartupPhase.ready) return const HomeShell();
        if (phase == StartupPhase.failed) return _StartupFailureScreen(startup: widget.startup);
        return const _StartupLoadingScreen();
      },
    );
  }
}

/// "The app is opening." Deliberately quiet: no fake progress, no percentage, nothing that
/// pretends to know how far the database is.
class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: TrackTheme.bg(dark),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Editorial.accent),
            ),
            const SizedBox(height: Editorial.s5),
            Text('Opening your data…', style: Editorial.title.copyWith(color: TrackTheme.label(dark))),
            const SizedBox(height: Editorial.s2),
            Text(
              'Everything stays on this device.',
              style: Editorial.caption.copyWith(color: TrackTheme.label3(dark)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "The app could not open your data." The one state in which the interface must **not**
/// be rendered: a dashboard over a database that did not load would show zeros the user
/// never entered, which is exactly the fabrication this codebase refuses everywhere else.
class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.startup});

  final AppStartup startup;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final failure = startup.failure;
    final issues = startup.state.startupIssues;

    return Scaffold(
      backgroundColor: TrackTheme.bg(dark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Editorial.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 22, color: Editorial.accent),
                    const SizedBox(width: Editorial.s3),
                    Expanded(
                      child: Text('Track Pro', style: Editorial.title.copyWith(color: TrackTheme.label(dark))),
                    ),
                  ],
                ),
                const SizedBox(height: Editorial.s5),
                Text(
                  'Your data could not be opened',
                  style: Editorial.title.copyWith(color: TrackTheme.label(dark)),
                ),
                const SizedBox(height: Editorial.s3),
                Text(
                  'Nothing has been changed or deleted: the app stopped before it loaded the '
                  'database, so there is no half-written state to repair. Trying again re-reads '
                  'it from the start.',
                  style: Editorial.body.copyWith(color: TrackTheme.label2(dark)),
                ),
                const SizedBox(height: Editorial.s4),
                Container(
                  padding: const EdgeInsets.all(Editorial.s4),
                  decoration: Editorial.card(border: Editorial.danger.withValues(alpha: .45)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        failure?.stage ?? 'Start-up',
                        style: Editorial.figure.copyWith(color: TrackTheme.label(dark)),
                      ),
                      const SizedBox(height: Editorial.s1),
                      Text(
                        failure?.detail ?? 'The database did not finish loading.',
                        style: Editorial.caption.copyWith(color: TrackTheme.label2(dark)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Editorial.s5),
                TrackFilledButton(label: 'Try again', onTap: () => unawaited(startup.retry())),
                if (issues.length > 1) ...[
                  const SizedBox(height: Editorial.s5),
                  Text('Also recorded', style: Editorial.caption.copyWith(color: TrackTheme.label3(dark))),
                  const SizedBox(height: Editorial.s2),
                  for (final issue in issues.reversed.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Editorial.s2),
                      child: Text(
                        issue,
                        style: Editorial.caption.copyWith(color: TrackTheme.label3(dark)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
