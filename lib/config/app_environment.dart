import 'package:flutter/foundation.dart';

/// Compile-time configuration — the single answer to "what kind of build is
/// this?".
///
/// Everything production-sensitive (the verification backend, legal URLs,
/// support contact) is read from `--dart-define` here, so a release build cannot
/// accidentally inherit a development behaviour, and there is exactly one place
/// to audit before shipping.
///
/// Note what is **not** here any more: a demo-data switch. Synthetic history is
/// no longer a build-time option at all — see `EntryRepository.bootstrap()`.
///
/// Build examples:
/// ```bash
/// # release (the only supported production wiring)
/// flutter build appbundle --release \
///   --dart-define=TRACK_VERIFY_URL=https://billing.example.com/billing/verify \
///   --dart-define=TRACK_TERMS_URL=https://example.com/track/terms \
///   --dart-define=TRACK_PRIVACY_URL=https://example.com/track/privacy \
///   --dart-define=TRACK_SUPPORT_EMAIL=support@example.com
/// ```
///
/// Development runs use the same wiring as release minus the URLs. There is no
/// demo-data flag to pass: fixtures live in `test/`.
class AppEnvironment {
  const AppEnvironment._();

  // ------------------------------------------------------------ billing backend
  static const String _verifyUrl = String.fromEnvironment('TRACK_VERIFY_URL');

  /// Absolute URL of the purchase-verification endpoint. Empty means "no
  /// backend configured", in which case the app **cannot** grant Pro: see
  /// `BillingService` — verification fails closed.
  static String get verifyUrl => _verifyUrl.trim();

  static bool get hasVerifyBackend => verifyUrl.isNotEmpty;

  static const int _verifyTimeoutMs = int.fromEnvironment('TRACK_VERIFY_TIMEOUT_MS', defaultValue: 10000);

  /// How long to wait before a verification request counts as "could not ask"
  /// rather than as a verdict. Bounded on purpose: this call sits behind the
  /// paywall closing, and a hang must never look like a rejection.
  static Duration get verifyTimeout =>
      Duration(milliseconds: _verifyTimeoutMs <= 0 ? 10000 : _verifyTimeoutMs);

  // ------------------------------------------------------------------- legal
  static const String termsUrl = String.fromEnvironment('TRACK_TERMS_URL');
  static const String privacyUrl = String.fromEnvironment('TRACK_PRIVACY_URL');
  static const String supportEmail = String.fromEnvironment('TRACK_SUPPORT_EMAIL');

  /// Hosted, reviewed policy pages. When empty the app shows the bundled
  /// documents instead of opening a URL that does not exist — the previous
  /// build linked to `track.app/terms`, a placeholder that was never
  /// provisioned, which is worse than no link at all.
  static bool get hasHostedPolicies => termsUrl.trim().isNotEmpty && privacyUrl.trim().isNotEmpty;

  // ------------------------------------------------------------------ versions
  /// Bumped by hand when the schema or export shape changes; recorded in exports
  /// so a user's backup can always be matched to the build that wrote it.
  static const String exportFormat = 'track.export.v1';

  /// Startup configuration errors. Non-empty means the build is misconfigured.
  ///
  /// Deliberately not an `assert`: asserts vanish in release, which is exactly
  /// when these matter. Three consumers, and it is worth knowing which is which:
  /// `main.dart` logs the list on a release start, Settings → Diagnostics shows it
  /// to whoever is looking, and [assertNotMisconfigured] is the entry point the
  /// release tooling calls. Nothing here can be checked after the fact, because
  /// the values are compiled in — which is why `.github/workflows/ci.yml` asserts
  /// the flags *before* the release build rather than inspecting the artifact.
  static List<String> validate() {
    final problems = <String>[];
    if (kReleaseMode && !hasVerifyBackend) {
      problems.add('No TRACK_VERIFY_URL: purchases cannot be verified, so Pro cannot be granted.');
    }
    if (kReleaseMode && !hasHostedPolicies) {
      problems.add('No TRACK_TERMS_URL/TRACK_PRIVACY_URL: store review requires reachable policy pages.');
    }
    for (final url in [verifyUrl, termsUrl, privacyUrl]) {
      if (url.isNotEmpty && !(url.startsWith('https://'))) {
        problems.add('Non-HTTPS URL in configuration: $url');
      }
    }
    return problems;
  }

  /// Release-tooling entry point: throw rather than ship a bad build.
  ///
  /// Callers: `test/app_environment_test.dart` pins the contract (and P-12 of
  /// `tools/release_gate.py` fails if that caller disappears), and the CI release
  /// job guards the same flags with a shell check. No *runtime* path calls it, on
  /// purpose: killing the app on a user's phone because the person who built it
  /// omitted a flag is worse than the failure `validate()` describes — Pro stays
  /// locked and everything else keeps working. A free build with no backend is a
  /// supported configuration, so `main()` logs and continues.
  static void assertNotMisconfigured() {
    final problems = validate();
    if (problems.isNotEmpty) {
      throw StateError('Track Pro build misconfigured:\n - ${problems.join('\n - ')}');
    }
  }
}
