# CI activation status

The workflow files now live in `.github/workflows/` (moved from `ci/workflows/`
in local commit `d329e86` on branch `arena/b98feb0e-trackpro`). **They are not
active on the remote**: the automation token used for this branch lacks the
GitHub `workflows` permission, so the push was rejected with:

```
! [remote rejected] arena/b98feb0e-trackpro -> arena/b98feb0e-trackpro
  (refusing to allow a GitHub App to create or update workflow
   `.github/workflows/ci.yml` without `workflows` permission)
```

The remote `rolexsir-org/trackpro` has no `.github/workflows/` directory at all
(verified 2026-11-01 via the Contents API).

## To activate

Do ONE of:

1. **Push with a credential that has `workflows` permission.** The branch
   already contains the two files; a normal `git push` from an account/token
   with the scope will activate them. The first push containing
   `.github/workflows/ci.yml` triggers the full gate run.
2. **GitHub web UI**: on the branch, "Add file" → create
   `.github/workflows/ci.yml` and `.github/workflows/normalize.yml` with the
   contents of the files in this directory. (The files are already in the
   local tree; copy them, do not re-author them.)
3. **Run the gates locally** on a machine with Flutter 3.47.7, JDK 17 and
   Android SDK 36:

   ```bash
   bash tools/run_gates.sh --build
   ```

   This is the only way to produce the Flutter evidence without activating CI.

## What the workflow does

`ci.yml` runs, on every push:

- `flutter pub get`, then `dart run build_runner build` and a `git diff` check
  that `lib/data/db/database.g.dart` is fresh;
- `dart format --set-exit-if-changed` on hand-written sources;
- `flutter analyze`;
- `flutter test`;
- the Python gates (`release_gate.py`, `gate_probe.py`, and the five
  `tools/*_audit.py` scanners);
- the Node billing suite (`npm --prefix billing_server test`);
- `flutter build apk --debug`, `flutter build apk --release`,
  `flutter build appbundle --release`;
- artifact checks: package name, version, target SDK, 64-bit ABIs, signing
  certificate, and a DEX check that the manifest-instantiated classes
  (`MainActivity`, `TrackWidgetReceiver`, `FocusSessionService`,
  `FocusBlockOverlay`, `FocusChannel`, `ScreenTimeChannel`) survived R8.

`normalize.yml` is a manual-dispatch job that runs `dart format` + drift codegen
with the real toolchain and commits the result. It commits with `[skip ci]` so a
formatting-only bot push does not re-run the 60-minute pipeline on itself.

## Two notes for whoever activates this

- `ci.yml` reads four optional secrets — `TRACK_VERIFY_URL`,
  `TRACK_TERMS_URL`, `TRACK_PRIVACY_URL`, `TRACK_SUPPORT_EMAIL` — and passes
  them as `--dart-define` to the APK build. Without them the build still
  succeeds with Pro permanently locked, which is the honest fallback for a
  fork; a Play artifact built without `TRACK_VERIFY_URL` is not shippable, and
  the job says so as a warning rather than failing, because the workflow is
  also the CI of this repository and must stay runnable without anyone's store
  configuration.
- Release artifacts in CI are **debug-signed on purpose**. No keystore or
  password ever enters CI. The Play upload AAB is built locally with
  `android/key.properties` per `docs/RELEASE.md` §2.

## Status caveat

No Flutter gate has ever run in this repository. The Python and Node gates pass
(53 release-gate checks; 78 billing tests), but `flutter analyze`,
`flutter test`, `flutter build apk` and `flutter build appbundle` are
**UNRUN**. The first CI run is the real test of the code; expect failures and
fix them. See `docs/PUBLISHING_GAPS.md` for the full gap register.
