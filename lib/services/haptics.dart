import 'package:flutter/services.dart';

/// One haptic vocabulary for the whole app, so every surface feels identical.
///
/// Two layers, in order of preference:
///
/// 1. **`track/haptics`** — a method channel into `MainActivity.kt`, which maps
///    each intent onto `HapticFeedbackConstants` (`CONFIRM`, `REJECT`,
///    `KEYBOARD_TAP`, `LONG_PRESS` on API 30+). Those are tuned per OEM *and*
///    respect the user's own touch-feedback / intensity settings.
/// 2. **Flutter's `HapticFeedback`** — the cross-platform fallback, used when the
///    channel is missing (unit tests, web, a build without the native overlay).
///
/// The channel is probed once; after the first `MissingPluginException` we stop
/// calling it, so every tap does not pay for an exception round-trip.
class Haptics {
  const Haptics._();

  static const MethodChannel _channel = MethodChannel('track/haptics');

  /// Global off-switch, wired to the Settings toggle (accessibility: some users
  /// hate haptics, and it costs nothing to let them say so).
  static bool enabled = true;

  static bool? _channelAvailable;
  static bool _probing = false;

  /// Tab switches, chip toggles, habit checks, stepper taps.
  static void selection() => _send('selection', HapticFeedback.selectionClick);

  /// Card press, quick-log tap.
  static void light() => _send('light', HapticFeedback.lightImpact);

  /// Committing a value: logging water, saving sleep, adding an expense.
  static void commit() => _send('commit', HapticFeedback.mediumImpact);

  /// Long-press context menu opening.
  static void hold() => _send('hold', HapticFeedback.mediumImpact);

  /// Destructive or negative: streak at risk, hidden tracker, reset.
  static void warning() => _send('warning', HapticFeedback.heavyImpact);

  /// Warm the channel up during app start so the first tap is not the probe.
  static Future<void> warmUp() async {
    if (_channelAvailable != null) return;
    _probing = true;
    try {
      await _channel.invokeMethod<void>('selection');
      _channelAvailable = true;
    } catch (_) {
      _channelAvailable = false;
    } finally {
      _probing = false;
    }
  }

  static void _send(String kind, Future<void> Function() fallback) {
    if (!enabled) return;

    // Channel already known to be missing → go straight to the fallback.
    if (_channelAvailable == false) {
      _fire(fallback);
      return;
    }
    if (_probing) return; // warmUp is already producing a haptic

    _channel
        .invokeMethod<void>(kind)
        .then((_) {
          _channelAvailable = true;
        })
        .catchError((Object _) {
          _channelAvailable = false;
          _fire(fallback);
        });
  }

  /// Fire-and-forget, and never let a platform hiccup surface as an error.
  static void _fire(Future<void> Function() f) {
    f().catchError((Object _) {});
  }
}
