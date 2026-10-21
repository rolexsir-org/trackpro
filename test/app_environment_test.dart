import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/config/app_environment.dart';

/// The build-configuration contract, pinned.
///
/// What this file can and cannot prove is the interesting part. Every value in `AppEnvironment`
/// comes from `String.fromEnvironment`, which is fixed when the *test VM* is compiled — a test
/// cannot set `TRACK_VERIFY_URL` and watch the consequence. There is nothing to inject, and that
/// is the design: a build that could flip its own configuration at runtime is a build whose
/// configuration cannot be trusted. So what is pinned here is the **rule**, evaluated against the
/// values this run really has.
///
/// Writing this file also closed a gap in the production wiring. `validate()` had two consumers
/// (`main.dart` logs it in release; Settings → Diagnostics shows it), while
/// `assertNotMisconfigured()` — documented as the CI entry point — had none. That is the shape
/// of the `tools/release_gate.py` disappearance this repo also had: a guard everyone believed was
/// running. `tools/release_gate.py` (P-12) now fails if the caller goes missing again, so the
/// documentation cannot rot quietly a second time.
void main() {
  group('AppEnvironment', () {
    test('the endpoint getter agrees with its own presence flag', () {
      // The pair has to stay in step: `main.dart` chooses the verifier from `hasVerifyBackend`
      // and `HttpPurchaseVerifier` parses `verifyUrl`. A flag that is true while the URL is
      // whitespace builds a verifier for `Uri.parse('')`, which fails as a network error instead
      // of as the misconfiguration it is.
      expect(AppEnvironment.hasVerifyBackend, AppEnvironment.verifyUrl.trim().isNotEmpty);
    });

    test('an unset dart-define reads as empty, never as a placeholder', () {
      // The failure this pins is the invented default. `defaultValue: 'https://billing.example.com'`
      // would make a CI build point at a host nobody controls, and a build that *thinks* it can
      // verify is worse than one that knows it cannot: purchases then sit pending forever with no
      // error anyone can read.
      expect(AppEnvironment.termsUrl.contains('example.com'), isFalse);
      expect(AppEnvironment.privacyUrl.contains('example.com'), isFalse);
      expect(AppEnvironment.supportEmail.contains('example.com'), isFalse);
      expect(AppEnvironment.verifyUrl, isNot(contains('localhost')));
    });

    test('the verification timeout has a floor a nonsense flag cannot remove', () {
      // `TRACK_VERIFY_TIMEOUT_MS=0` maps back to the default inside the getter. A zero timeout
      // makes every verification "time out" before it starts, which reads to the user as a
      // rejected receipt — and this call sits behind the paywall closing.
      expect(AppEnvironment.verifyTimeout.inMilliseconds, greaterThan(0));
      expect(
        AppEnvironment.verifyTimeout,
        const Duration(seconds: 10),
        reason: 'no dart-define is set in a test run, so the default must be what ships',
      );
    });

    test('a debug run reports no configuration problems', () {
      expect(kReleaseMode, isFalse, reason: 'this file pins debug behaviour; the release rules are checked by CI');
      expect(
        AppEnvironment.validate(),
        isEmpty,
        reason:
            'validate() gates its two release-only rules on kReleaseMode, so a test run must '
            'never fail for a missing --dart-define. If this fails, either the guard stopped '
            'being release-only (every `flutter test` now needs store flags to pass) or a '
            'non-HTTPS URL was compiled in.',
      );
    });

    test('assertNotMisconfigured is callable and passes on a debug build', () {
      // The point of this test is the call itself: the entry point documented for release tooling
      // has to exist, have a caller, and agree with `validate()` — the gate checks for the caller.
      AppEnvironment.assertNotMisconfigured();
    });
  });
}
