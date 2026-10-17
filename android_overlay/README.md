# android_overlay/ — SUPERSEDED (historical)

This directory predates the committed Android host. It was written when the
repository had **no** `android/` directory and documented what would need to be
merged into a `flutter create` output.

**That merge has now been performed and committed: the canonical Android host
lives in [`../android/`](../android/).** Everything in here — Kotlin sources,
manifest entries, Gradle additions, proguard rules, widget metadata — exists in
`android/` in its final, merged form.

Do **not** run `apply_overlay.sh` any more: it would copy files onto an already
complete host and risk re-introducing stale copies.

What this directory is still good for:

- The manifest file here carries the full written rationale for every
  permission (and for every permission deliberately *not* requested) — the
  committed manifest references it.
- `wear/HOW_TO_ADD_WEAR.md` documents the optional, deliberately-disabled
  Wear OS module.

If `android/` and this directory ever disagree, `android/` wins.
