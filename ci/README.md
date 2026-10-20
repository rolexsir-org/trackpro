# CI workflow files (pending activation)

The real location for these files is `.github/workflows/`, but the automation
token used to prepare this branch is not allowed to push workflow files
(GitHub requires the `workflows` permission for that path — confirmed again
2026-10-20: the push was rejected with exactly that error).

Both files below are current (Flutter 3.47.7-pinned, with the doctor /
env-check / debug-build / lockfile-artifact steps added in the 2026-10-20
upgrade). To activate CI, do ONE of:

1. **GitHub web UI**: on this branch, "Add file" → `.github/workflows/ci.yml`
   and `.github/workflows/normalize.yml`, pasting the contents of the files in
   this directory unchanged; or
2. **Locally**: `git pull`, then
   `git mv ci/workflows/ci.yml .github/workflows/ci.yml`
   `git mv ci/workflows/normalize.yml .github/workflows/normalize.yml`
   commit and push with your own credentials.

The first push containing `.github/workflows/ci.yml` triggers the full gate
run automatically: codegen freshness, `dart format`, `flutter analyze`,
`flutter test`, the Python audit gates (`release_gate`, `gate_probe`, and the
five `tools/*_audit.py` scanners), then the release APK + AAB with artifact
identity/signing checks and a check that the manifest-instantiated classes
survived R8.

Two notes for whoever activates this:

* `ci.yml` reads four optional secrets — `TRACK_VERIFY_URL`, `TRACK_TERMS_URL`,
  `TRACK_PRIVACY_URL`, `TRACK_SUPPORT_EMAIL` — and passes them as
  `--dart-define` to the APK build. Without them the build still succeeds with
  Pro permanently locked, which is the honest fallback for a fork; a Play
  artifact built without `TRACK_VERIFY_URL` is not shippable, and the job says
  so as a warning rather than failing, because the workflow is also the CI of
  this repository and must stay runnable without anyone's store configuration.
* `normalize.yml` commits with `[skip ci]`. Keep that marker: without it a
  formatting-only bot push re-runs the whole 60-minute pipeline on itself.
