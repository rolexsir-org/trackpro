# CI workflow files (pending activation)

The real location for these files is `.github/workflows/`, but the automation
token used to prepare this branch is not allowed to push workflow files
(GitHub requires the `workflows` permission for that path).

To activate CI, do ONE of:

1. **GitHub web UI**: on this branch, "Add file" → `.github/workflows/ci.yml`
   and `.github/workflows/normalize.yml`, pasting the contents of the files in
   this directory unchanged; or
2. **Locally**: `git pull`, then
   `git mv ci/workflows/ci.yml .github/workflows/ci.yml`
   `git mv ci/workflows/normalize.yml .github/workflows/normalize.yml`
   commit and push with your own credentials.

The first push containing `.github/workflows/ci.yml` triggers the full gate
run (format, codegen freshness, analyze, test, release APK+AAB + artifact
verification) automatically.
