import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:track/config/pro_config.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/main.dart' show TrackTheme;
import 'package:track/screens/commitment_sheets.dart';
import 'package:track/screens/log_sheets.dart';
import 'package:track/screens/paywall_screen.dart';
import 'package:track/screens/settings_screen.dart';
import 'package:track/screens/startup_gate.dart';
import 'package:track/state/app_startup.dart';
import 'package:track/state/app_state.dart';
import 'package:track/widgets/glass.dart';

List<String> underlined(WidgetTester tester) {
  final out = <String>[];
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    var bad = false;
    p.text.visitChildren((span) {
      if (span is TextSpan && span.style?.decoration == TextDecoration.underline) bad = true;
      return true;
    });
    if (bad) out.add(p.text.toPlainText().replaceAll('\n', ' '));
  }
  return out;
}

/// Regression: `showGlassSheet` built its sheet in a dialog route with no Material
/// above it, so Quick add, the routine templates/editor and the Momentum explainer
/// drew every line of text with Flutter's yellow double-underline fallback style.
void main() {
  for (final dark in [false, true]) {
    testWidgets('no screen, sheet, dialog or toast renders fallback-underlined text (dark=$dark)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final db = TrackDatabase.forTesting(NativeDatabase.memory());
      final state = AppState(repo: EntryRepository(db), commitmentRepo: CommitmentRepository(db));
      final startup = AppStartup(state: state, essential: () async => state.load());
      await tester.runAsync(startup.start);
      await tester.runAsync(state.completeOnboarding);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: TrackTheme.light(), darkTheme: TrackTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light, home: StartupGate(startup: startup))));
      await tester.pump();
      final report = <String, List<String>>{};
      void scan(String where) { final u = underlined(tester); if (u.isNotEmpty) report[where] = u; tester.takeException(); }
      for (final (i, name) in [(0,'Today'),(1,'Routines'),(2,'Momentum'),(3,'Insights'),(4,'Profile')]) {
        state.setTab(i); await tester.pump(const Duration(milliseconds: 400)); scan('tab $name');
      }
      state.setTab(0); await tester.pump();
      final ctx = tester.element(find.byType(Scaffold).first);
      Future<void> open(String name, void Function() f) async {
        f(); await tester.pump(); await tester.pump(const Duration(milliseconds: 600)); scan(name);
        final nav = Navigator.of(ctx); if (nav.canPop()) nav.pop(); await tester.pump(const Duration(milliseconds: 600)); tester.takeException();
      }
      await open('glassSheet', () => showGlassSheet<void>(ctx, title: 'T', subtitle: 'S', body: const Text('body')));
      await open('quickAdd', () => showQuickAdd(ctx));
      await open('confirm', () => showTrackConfirm(ctx, title: 'T', body: 'B', confirmLabel: 'OK'));
      await open('dialog', () => showTrackDialog(ctx, title: 'T', body: 'B'));
      await open('legal', () => showLegalSheet(ctx, kind: 'privacy'));
      await open('templates', () => showTemplatePicker(ctx));
      await open('explainer', () => showMomentumExplainer(ctx));
      await open('editor', () => showCommitmentEditor(ctx));
      await open('paywall', () => showPaywall(ctx, trigger: PaywallTrigger.settings));
      showTrackToast(ctx, 'toast'); await tester.pump(const Duration(milliseconds: 200)); scan('toast');
      await tester.pump(const Duration(seconds: 4));
      expect(report, isEmpty,
          reason: 'text drawn outside a Material inherits the yellow-underline fallback style');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });
  }
}
