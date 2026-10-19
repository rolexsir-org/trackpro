import 'package:flutter/material.dart';

import '../config/design_system.dart';
import 'trackers_screen.dart';

/// The pushed wrapper for the trackers screen.
///
/// Trackers are deliberately **not** a tab: the tab bar is the habit loop
/// (Today → Routines → Momentum → Insights → Profile), and a management list does not
/// belong in it. Everything that points at tracker management — Routines, and Profile's
/// single "All trackers" row — pushes this page, so there is one route and one
/// implementation rather than a screen pretending to be a section. Profile used to carry
/// two rows for this one destination ("Measurements" and "Manage trackers"); they were
/// merged, because two names for one page is how a settings screen stops being trusted.
///
/// The class keeps its original name for import compatibility; what it wraps is the
/// tracker list, and `TrackersScreen` brings its own header and its own back control.
/// It used to add a second "Back" bar on top of that header, which is why a screen
/// with one title showed two.
class MeasurementsPage extends StatelessWidget {
  const MeasurementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Editorial.canvas,
      // SafeArea, then the screen as it draws itself: no extra bar, no second title.
      body: SafeArea(child: const TrackersScreen()),
    );
  }
}
