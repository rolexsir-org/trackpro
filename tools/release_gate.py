#!/usr/bin/env python3
"""Track's release gate — the machine-checkable half of the pre-flight checklist.

    python3 tools/release_gate.py            # exit 0 = clean, exit 1 = problems listed
    python3 tools/release_gate.py --list     # what each check means, and why it exists

WHAT THIS IS
------------
A structural scanner over the repository that catches the class of defect a build cannot:
things that compile, ship, and are simply wrong. Every check here was earned — each one
encodes a defect actually found in this codebase by reading, and the list is ordered by
how much it would have cost to discover at runtime instead.

`tools/gate_probe.py` breaks each rule on purpose, one at a time, and requires this gate
to fire and the tree to come back clean. A check that no probe can fire is not a check;
it is a comment that runs.

WHAT THIS IS NOT
----------------
It is not a type checker and does not pretend to be. `flutter analyze`, `flutter test`
and `flutter build` are the authority on types, behaviour and linkage, and on a machine
with the Flutter SDK they run *before* this gate (`docs/RELEASE.md`). What this tool can
legitimately assert is only what a text scanner can see: that a named symbol exists, that
a banned pattern is absent, that two files agree about a string. A clean run here is not
a shipping approval, and it never says anything about whether the app works.

Two rules of authorship, both learned the hard way in this repo:

  * Match against `code()` / `prose()`, never raw text. Half the "fabricated demo numbers"
    in `lib/` live inside the comments that explain their removal, and a naive grep
    reports those as live defects — which is how an audit stops being trusted.
  * A check that has to be weakened to pass has to be deleted instead, with a note in
    `docs/PRODUCT_COHERENCE_REPORT.md`. Checks removed for that reason are recorded there
    rather than quietly dropped.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LIB = ROOT / 'lib'
ANDROID = ROOT / 'android'
KT_DIR = ANDROID / 'app/src/main/kotlin'

sys.path.insert(0, str(HERE))
from dart_source import strip_comments, strip_comments_and_strings  # noqa: E402

VERBOSE = '--list' in sys.argv or '-v' in sys.argv
CHECKS: list[tuple[str, str, str, callable]] = []


def check(check_id: str, title: str, explains: str = ''):
    def deco(fn):
        CHECKS.append((check_id, title, explains, fn))
        return fn

    return deco


# --------------------------------------------------------------------------------------
# source access
# --------------------------------------------------------------------------------------

_cache: dict[Path, str] = {}


def raw(rel: str) -> str:
    """File text, verbatim. Right input for gradle/XML/Kotlin and for copy checks."""
    p = ROOT / rel
    if p not in _cache:
        _cache[p] = p.read_text(encoding='utf-8', errors='replace') if p.exists() else ''
    return _cache[p]


def code(rel: str) -> str:
    """Dart text with comments removed and string bodies blanked — for symbol/pattern rules."""
    return strip_comments_and_strings(raw(rel))


def prose(rel: str) -> str:
    """Dart text with comments removed but literals intact — for shipped-copy rules.

    `code()` is the wrong input here: it blanks the inside of every literal, so the one
    place a shipped string exists is exactly where that function erases it. The reverse
    mistake is worse, and was actually made: a comment stripper that does not track string
    literals eats the rest of any line containing a URL, because `https://` reads as a
    comment start — which quietly blinds every copy check in this file to links.
    """
    return strip_comments(raw(rel))


def dart_paths(sub: str) -> list[Path]:
    base = ROOT / sub
    return sorted(p for p in base.rglob('*.dart') if not p.name.endswith('.g.dart'))


def dart_rel(sub: str = 'lib') -> list[str]:
    return [str(p.relative_to(ROOT)) for p in dart_paths(sub)]


def rel_of(p: Path) -> str:
    return str(p.relative_to(ROOT))


def require(rel: str, needle: str, why: str) -> list[str]:
    """A REQUIRE check: if the symbol is gone, the guarantee it encodes is gone with it."""
    if needle in code(rel):
        return []
    return [f'{rel}: {why} — `{needle.strip()}` is no longer in this file']


def ban(pattern: str, where: list[tuple[str, str]], why: str) -> list[str]:
    """A BAN check: the pattern must not appear in the code text of any listed file."""
    hits, rx = [], re.compile(pattern)
    for rel, scope in where:
        body = code(rel)
        m = rx.search(body)
        if m:
            hits.append(f'{rel}:{body[:m.start()].count(chr(10)) + 1}: {scope} — {why}')
    return hits


def body_of(rel: str, header: str, mode: str = 'code'):
    """A member's text: from `header` up to the line that closes it (`  }` at two-space indent).

    Splitting on a regex like `\((.*?)\n  \}` looks equivalent and is not: for a multi-line
    parameter list it stops at the `})` that *ends the signature*, so the check reads nothing but
    the parameters and reports healthy code as broken. Two checks here were wrong exactly that way
    on their first run, which is the whole argument for probing a gate.
    """
    # `mode` matters: a rule about shipped *copy* has to read `prose()`, because `code()`
    # blanks string bodies and would then see a message that is not there.
    src = code(rel) if mode == 'code' else prose(rel)
    i = src.find(header)
    if i < 0:
        return None
    # The closer is a line whose *entire* content is `  }`. Matching the prefix would stop at
    # `  }) {`, which is the end of the parameter list rather than of the member — the same
    # trap as the regex it replaced.
    offset = src[:i].count('\n')
    lines = src.split('\n')
    for k in range(offset + 1, len(lines)):
        if lines[k] == '  }':
            return '\n'.join(lines[offset:k])
    return None


def line_of(rel: str, needle: str) -> int:
    idx = raw(rel).find(needle)
    return -1 if idx < 0 else raw(rel)[:idx].count('\n') + 1


# ======================================================================================
# P-01 .. P-06 — no invented product
# ======================================================================================

@check('P-01', 'no synthetic-data machinery reaches the app',
       'A generator that fills the database makes every statistic on screen unfalsifiable, '
       'including the ones the user believes about themselves.')
def c_demo_machinery():
    out = []
    for rel in dart_rel('lib'):
        body = code(rel)
        for rx, why in [
            (r'\bseedDemo|\bDemoSeed|wipeAndReseed|\bseedSamples?\b', 'a demo/seed entry point'),
            (r'\bDemoFixtures\b|\bdemoData\b', 'a demo dataset'),
        ]:
            m = re.search(rx, body)
            if m:
                out.append(f'{rel}: {why} (`{m.group(0).strip()}`) is reachable from lib/')
    if re.search(r'bootstrap\([^)]*seed', code('lib/main.dart'), re.S):
        out.append('lib/main.dart: `bootstrap()` takes a seeding argument — a debug-only switch a '
                   'release build can inherit')
    return out


@check('P-02', 'test fixtures are not compiled into the app',
       'Anything importable from lib/ ships. A fixture imported into production code is a '
       'fabricated record with a test-only excuse.')
def c_fixtures():
    out = []
    for rel in dart_rel('lib'):
        # `prose()`, not `code()`: an import path is a *string literal*, and `code()` blanks
        # literal bodies — which made this check unable ever to fire. `gate_probe.py` P-02 is
        # what found that, and it is the reason every check in this file has a probe.
        body = prose(rel)
        if re.search(r"import\s+'[^']*test/fixtures", body) or re.search(r'\bFakeDatabase\b', body):
            out.append(f'{rel}: reaches a test fixture; fixtures belong to `test/` only')
    return out


@check('P-03', 'no fabricated numbers or invented people in shipped copy',
       'Statistics must come from the user\'s own rows. Each string below was live in this app '
       'at some point: users were shown a stranger\'s name and a stranger\'s streak.')
def c_fabricated_copy():
    banned = ['1,284', '23-day streak', '28 days of history', '12 days in a row',
              'Jai Deshmukh', 'since 17 Sep']
    out = []
    for rel in dart_rel('lib'):
        body = prose(rel)
        for s in banned:
            m = re.search(re.escape(s), body)
            if m:
                out.append(f'{rel}:{body[:m.start()].count(chr(10)) + 1}: fabricated copy '
                           f'`{s}` appears outside a comment')
    return out


@check('P-04', 'no placeholder URLs or template secrets',
       'A placeholder that ships is a broken promise the user can tap.')
def c_placeholders():
    out = []
    for rel in dart_rel('lib'):
        body = prose(rel)
        for rx, why in [
            (r'track\.app/(?:terms|privacy)', 'a placeholder legal URL'),
            (r'\bREPLACE_?ME\b|\byour-?api-?key\b|AIza[0-9A-Za-z_\-]{10,}|sk_live_[0-9A-Za-z]{6,}',
             'a template or real-looking credential'),
        ]:
            if re.search(rx, body):
                out.append(f'{rel}: {why}')
    return out


@check('P-05', 'no unfinished-work markers in shipped code',
       'A TODO in a released build is a defect somebody already knew about and priced as '
       '"not now" for the user.')
def c_todo():
    out = []
    for rel in dart_rel('lib'):
        body = raw(rel)
        m = re.search(r'\b(TODO|FIXME|XXX|HACK)\b', body)
        if m:
            out.append(f'{rel}:{body[:m.start()].count(chr(10)) + 1}: `{m.group(0)}` left in the app')
    if KT_DIR.exists():
        for p in sorted(KT_DIR.rglob('*')) + sorted((ANDROID / 'app/src/main').rglob('*.xml')):
            if p.is_file() and p.suffix in {'.kt', '.java', '.xml'}:
                body = p.read_text(encoding='utf-8', errors='replace')
                m = re.search(r'\b(TODO|FIXME|XXX)\b', body)
                if m:
                    out.append(f'{rel_of(p)}:{body[:m.start()].count(chr(10)) + 1}: '
                               f'`{m.group(0)}` in host code')
    return out


@check('P-06', 'provenance is labelled where data may not be the user\'s',
       'Imported rows are somebody else\'s measurements until the user has checked them. On a '
       'screen whose whole purpose is "this is your life", the label is the only honesty left.')
def c_provenance():
    if "'Sample data (not yours)'" in prose('lib/data/db/database.dart'):
        return []
    return ['lib/data/db/database.dart: the `demo`/health label in `sourceLabel` that tells a '
            "user a row is not theirs (`'Sample data (not yours)'`) is gone"]


# ======================================================================================
# P-07 .. P-09 — secrets, signing, backups
# ======================================================================================

@check('P-07', 'no keystore or signing password in the tree',
       'A signing key in git is a signing key that has to be rotated, in a repo where history '
       'cannot be rewritten. `key.properties` is ignored on purpose; this catches the day one '
       'of them is force-added.')
def c_secrets():
    try:
        r = subprocess.run(['git', 'ls-files'], cwd=ROOT, capture_output=True, text=True, timeout=30)
        files = r.stdout.split() if r.returncode == 0 else []
    except Exception:
        files = []
    if not files and ANDROID.exists():  # an exported tree, not a checkout
        files = [rel_of(p) for p in ANDROID.rglob('*') if p.is_file()]
    out = []
    for f in files:
        if re.search(r'\.(jks|keystore|p12)$', f) or f.endswith('key.properties') or f.endswith('credentials.json'):
            out.append(f'{f}: a signing/credential artefact must never be tracked')
    for f in [x for x in files if x.endswith('build.gradle.kts')]:
        if re.search(r'(storePassword|keyPassword|keyAlias|storeFile)\s*=\s*["\'][^"\']+["\']', raw(f)):
            out.append(f'{f}: a signing value is a literal instead of something read from '
                       'key.properties — the release build then becomes possible without the '
                       'secret, which is the opposite of the arrangement')
    return out


@check('P-08', 'release signing keeps its debug fallback and shrinks resources',
       'With no keystore on the machine, `assembleRelease` must still produce an APK: a build '
       'that dies here is indistinguishable from a broken pipeline, which is how a signing '
       'question turns into a day of guessing.')
def c_signing_fallback():
    rel = 'android/app/build.gradle.kts'
    body = raw(rel)
    out = []
    if 'keystorePropertiesFile' not in body:
        out.append(f'{rel}: the release signing config no longer reads key.properties from disk')
    if 'signingConfigs.getByName("debug")' not in body:
        out.append(f'{rel}: no fallback to the debug key, so an unsigned smoke build is a build '
                   'failure rather than an unsigned APK')
    if re.search(r'isMinifyEnabled\s*=\s*true', body) and 'isShrinkResources' not in body:
        out.append(f'{rel}: code shrinking is on but `isShrinkResources` is not, so every unused '
                   'drawable ships')
    return out


@check('P-09', 'no cloud backup of the local database',
       '`allowBackup="true"` would put a user\'s health, expense and cycle history in a Google '
       'backup they never agreed to, in a design that promises those never leave the device.')
def c_backup():
    body = raw('android/app/src/main/AndroidManifest.xml')
    out = []
    if 'android:allowBackup="false"' not in body:
        out.append('android/app/src/main/AndroidManifest.xml: `android:allowBackup` is not "false"')
    if 'android:fullBackupContent="false"' not in body:
        out.append('android/app/src/main/AndroidManifest.xml: `android:fullBackupContent` is not '
                   '"false" — a device-transfer still copies the database')
    if re.search(r'android:usesCleartextTraffic="true"', body):
        out.append('android/app/src/main/AndroidManifest.xml: cleartext traffic is enabled '
                   'app-wide to save writing one https:// URL')
    return out


# ======================================================================================
# P-10 .. P-17 — the billing seam must fail closed
# ======================================================================================

@check('P-10', 'an entitlement needs a server verdict before it grants anything',
       'The whole paywall rests on one predicate. It is the cheapest check in this file and the '
       'most expensive thing to lose: without it a forged local claim is Pro.')
def c_fail_closed():
    out = require('lib/config/pro_config.dart', 'if (!verified) return false;',
                  'the fail-closed rule inside `Entitlement.active`')
    out += require('lib/config/pro_config.dart', 'if (pending) return false;',
                   'the rule that a pending purchase is not a paid one')
    return out


@check('P-11', 'provisional entitlements are marked pending',
       'A client-side "I own it" may paint the UI for a few seconds, but it has to be flagged '
       'unproven so nothing downstream mistakes it for a receipt.')
def c_provisional_pending():
    rel = 'lib/config/pro_config.dart'
    block = body_of(rel, 'static Entitlement provisional(')
    if block is None:
        return [f'{rel}: `Entitlement.provisional` is gone — restore and pending-purchase paths '
                'have nowhere to express "claimed, not confirmed"']
    out = []
    # Both grant branches (lifetime, subscription) must be marked. One occurrence would leave the
    # other handing out `active` entitlements from nothing but a cache read.
    n = block.count('pending: true')
    if n < 2:
        out.append(f'{rel}: `provisional()` marks {n} of its 2 grant branches `pending: true`, so '
                   'a cache-only claim passes `active` and the fail-closed rule is bypassed by the '
                   'object invented to represent uncertainty')
    return out

@check('P-12', 'no verifier is wired except when a backend exists',
       'The dev stub is only a dev stub while somebody chooses it. Wired silently into a release '
       'build it removes the paywall from every install, and no test would notice.')
def c_verifier_wiring():
    out = require('lib/main.dart', 'AppEnvironment.hasVerifyBackend',
                  'the switch that decides which verifier the app gets')
    body = code('lib/main.dart')
    if re.search(r'StaticProductVerifier\(|LocalOnlyVerifier\(', body) and 'hasVerifyBackend' not in body:
        out.append('lib/main.dart: a stub verifier is constructed with no backend check in sight')
    # `validate()` must have a runtime consumer, or the configuration errors this class exists to
    # compute are thrown away; and `assertNotMisconfigured()` must have *some* caller, because its
    # doc promises a release-script entry point. A function documented as "called by CI" that
    # nothing calls is the same pattern that let `tools/release_gate.py` go missing unnoticed.
    if 'AppEnvironment.validate()' not in '\n'.join(code(r) for r in dart_rel('lib')):
        out.append('lib/: nothing calls `AppEnvironment.validate()` — the configuration errors this '
                   'class exists to compute are never read')
    callers = [r for r in dart_rel('lib') + dart_rel('test')
               if 'assertNotMisconfigured' in code(r)
               and 'static void assertNotMisconfigured' not in raw(r)]
    if not callers:
        out.append('lib/config/app_environment.dart: `assertNotMisconfigured()` is documented as '
                   'the CI entry point and has no caller — pin it in a test or delete it; a '
                   'documented-but-unwired guard is worse than none, because it is trusted')
    ci = ROOT / '.github/workflows/ci.yml'
    if ci.exists() and 'TRACK_VERIFY_URL' not in ci.read_text(encoding='utf-8'):
        out.append('.github/workflows/ci.yml: the release job builds without asserting the '
                   'verification endpoint, so CI can produce a build that cannot grant Pro at all')
    return out

@check('P-13', 'the purchase flow acknowledges before it verifies',
       'If verification runs first and the server is unreachable, the purchase is never '
       'acknowledged and Google keeps re-offering a product the user already paid for.')
def c_ack_order():
    rel = 'lib/services/billing_service.dart'
    body = raw(rel)
    a = body.find('_iap.completePurchase')
    v = body.find('await _verify(productId:')
    if a < 0 or v < 0:
        return [f'{rel}: the acknowledgement/verification pair this check orders is not both '
                'present (`_iap.completePurchase`, `_verify(productId:`) — it cannot run on code '
                'that renamed one, so fix the check and the note together, never the rule']
    if a > v:
        return [f'{rel}: `completePurchase` runs after verification (line '
                f'{line_of(rel, "_iap.completePurchase")} vs {line_of(rel, "await _verify(productId:")}), '
                'so a failed verification strands a paid purchase']
    return []


@check('P-14', 'receipts are never logged',
       'A purchase token in a logcat dump or an analytics event is a transferable claim on '
       'somebody else\'s subscription.')
def c_tokens_not_logged():
    out = []
    for rel in ['lib/services/billing_service.dart', 'lib/config/pro_config.dart',
                'lib/state/app_state.dart', 'lib/services/pro_analytics.dart']:
        for i, ln in enumerate(raw(rel).split('\n'), 1):
            s = ln.strip()
            if s.startswith('//'):
                continue
            if re.search(r'(debugPrint|developer\.log|_analytics\??\.log|analytics\.log|print)\s*\(', s) \
                    and re.search(r'purchaseToken|\btoken\b', s):
                out.append(f'{rel}:{i}: a log statement names a token')
    return out


@check('P-15', 'exactly one verifier seam',
       'This repo shipped two `PurchaseVerifier` declarations in one file with different '
       'signatures. Both looked used, neither matched the other, and nothing but reading caught '
       'it — so the shape of the seam is checked textually.')
def c_one_verifier_seam():
    body = code('lib/services/billing_service.dart')
    out = []
    decls = re.findall(r'^(?:abstract\s+|sealed\s+|interface\s+)?class PurchaseVerifier\b', body, re.M)
    if len(decls) != 1:
        out.append(f'lib/services/billing_service.dart: {len(decls)} declarations of '
                   '`PurchaseVerifier` — exactly one is allowed, and a second always means a '
                   'stale copy survived a rename')
    if 'String signature' in body and 'signature' in body:
        out.append('lib/services/billing_service.dart: the seam still carries a Play `signature` '
                   'parameter, which in-app billing never hands the app — a server that "checks" '
                   'it is checking a value this client invented')
    return out


@check('P-16', 'product ids are matched exactly, never fuzzily',
       '`planForProduct` maps a store id to a plan. Substring matching there means an unknown id '
       'can inherit a plan — including a lifetime one — and the receipt screen then lies about '
       'what the user bought.')
def c_exact_product_matching():
    body = code('lib/config/pro_config.dart')
    m = re.search(r'static ProPlan\? planForProduct\(String productId\) \{(.*?)\n  \}', body, re.S)
    if not m:
        return ['lib/config/pro_config.dart: `planForProduct` is not in a shape this check can '
                'read; re-derive the rule rather than deleting it']
    fn = m.group(1)
    out = []
    if re.search(r"\.contains\(\s*'", fn):
        out.append('lib/config/pro_config.dart: planForProduct matches ids by substring — any id '
                   'containing "lifetime" would be granted a lifetime plan')
    if 'firstWhereOrNull' in fn:
        out.append('lib/config/pro_config.dart: planForProduct uses `firstWhereOrNull`, which is '
                   'not imported here — it lives in package:collection and that is only a '
                   'transitive dependency, so this compiles nowhere')
    return out


@check('P-17', 'paywall copy matches the refund and trial rules that exist',
       'Copy is a promise. "14-day no-questions refunds" promised a policy this app does not '
       'grant, and "you will not be charged during the trial" sat next to a trial screen with no '
       'way to cancel.')
def c_copy_promise():
    out = []
    body = prose('lib/config/pro_config.dart')
    if re.search(r'14-day no-questions', body):
        out.append('lib/config/pro_config.dart: the app promises a refund window it does not '
                   'grant; `docs/REFUND_PLAYBOOK.md` is the authority on what it can say')
    if re.search(r'You will not be charged during the trial', body) \
            and 'launchBillingProfile' not in code('lib/screens/paywall_screen.dart'):
        out.append('lib/config/pro_config.dart: `trialTimeline` promises no charge during the '
                   'trial while the trial screen offers no cancel path — either wire Play\'s '
                   'subscription page there or stop making the promise')
    return out


# ======================================================================================
# P-18 .. P-22 — the Android host must match the Dart side
# ======================================================================================

@check('P-18', 'every manifest component exists in the host sources',
       'A manifest that names a class the APK does not contain crashes at the moment the system '
       'instantiates it. For a widget or a foreground service that is never at launch, so it '
       'walks straight through a smoke test.')
def c_manifest_components():
    manifest = raw('android/app/src/main/AndroidManifest.xml')
    kotlin = ''
    if KT_DIR.exists():
        kotlin = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in KT_DIR.rglob('*.kt'))
    out = []
    # <activity-alias android:name=".ViewPermissionUsageActivity"> is an alias whose targetActivity
    # is the class, and this repo has exactly one (the Health Connect rationale). Treating an alias
    # name as a class would demand a class that must not exist.
    alias_names = set(re.findall(r'android:name="([^"]+)"',
                                 '\n'.join(re.findall(r'<activity-alias\b.*?/?>', manifest, re.S))))
    for _tag, decl in re.findall(r'<(activity|service|receiver|provider)\b[^>]*?android:name="([^"]+)"',
                                 manifest, re.S):
        # A leading dot is how a manifest says "in my package". `com.dexterous.…` is a plugin's
        # class, and looking for it in this app's sources invents a defect.
        if decl in alias_names or not decl.startswith('.'):
            continue
        name = decl.split('.')[-1]
        if not name or name[0].islower():
            continue
        if not re.search(r'\bclass\s+' + re.escape(name) + r'\b', kotlin):
            out.append(f'android/app/src/main/AndroidManifest.xml: `{decl}` is declared as a '
                       'component but no such class exists under android/app/src/main/kotlin — the '
                       'system throws when it instantiates it, which is not at launch')
    return out

@check('P-19', 'method channels agree on both sides',
       'The Dart/native contract is a set of strings with no compiler on either end. '
       '`MissingPluginException` is what a typo costs here, and the user meets it by tapping the '
       'feature, not by launching the app.')
def c_channel_parity():
    # Channel and method names are string literals, so this scan must run over `prose()`.
    # `code()` blanks literal bodies, and the check silently compared nothing at all.
    dart = '\n'.join(prose(r) for r in dart_rel('lib'))
    dart_strings = '\n'.join(prose(r) for r in dart_rel('lib'))
    kt = ''
    if KT_DIR.exists():
        kt = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in KT_DIR.rglob('*.kt'))
    out = []
    for ch in sorted(set(re.findall(r"MethodChannel\(\s*'([\w./]+)'", dart))):
        if ch not in kt:
            out.append(f'channel `{ch}` is constructed in Dart and never named in the host '
                       'sources — every call on it throws MissingPluginException')
    # Handlers the *wearable* invokes (WearSync's phone side) are legitimately absent from Dart,
    # so that file\'s vocabulary is exempted by name instead of by a rule that gets forgotten.
    wear = KT_DIR / 'com/track/app/WearSync.kt'
    wear_methods = set(re.findall(r'"([A-Za-z][\w./]*)"', wear.read_text(encoding='utf-8'))) if wear.exists() else set()
    for h in sorted(set(re.findall(r'(?:when\s*\(\s*call\.method\s*\)\s*\{|\bcall\.method\s*==\s*)\s*"([A-Za-z][\w./]*)"', kt))):
        if h in wear_methods:
            continue
        if f"'{h}'" not in dart_strings and f"'{h}'" not in dart:
            out.append(f'host handler `{h}` has no Dart caller — the UI will look like the '
                       'feature did nothing')
    return out


@check('P-20', 'Gradle pins what it must and agrees with itself',
       'A dynamic `+` version or a Kotlin/Compose-plugin mismatch makes CI build a different app '
       'than the one that was tested, and the failure shows up as an internal error message about '
       'a plugin nobody touched.')
def c_gradle_pins():
    out = []
    for rel in ['android/settings.gradle.kts', 'android/build.gradle.kts', 'android/app/build.gradle.kts',
                'android/gradle.properties']:
        body = raw(rel)
        for m in re.finditer(r'["\'][\w.:\-]+\+["\']', body):
            out.append(f'{rel}: a dynamic version `{m.group(0)}` — the build is not reproducible')
    settings = raw('android/settings.gradle.kts')
    ks = re.search(r'org\.jetbrains\.kotlin\.android"?\)?\s*version\("([\d.]+)"', settings)
    cs = re.search(r'org\.jetbrains\.kotlin\.plugin\.compose"\)\s*version\("([\d.]+)"', settings)
    if ks and cs and ks.group(1) != cs.group(1):
        out.append(f'android/settings.gradle.kts: Kotlin {ks.group(1)} vs Compose compiler '
                   f'{cs.group(1)} — the Compose plugin tracks the Kotlin version exactly')
    app = raw('android/app/build.gradle.kts')
    m = re.search(r'minSdk\s*=\s*(\d+)', app)
    if m and int(m.group(1)) > 26:
        out.append(f'android/app/build.gradle.kts: minSdk {m.group(1)} excludes devices the docs '
                   'claim are supported')
    if 'flutter.minSdkVersion' not in app and m is None:
        out.append('android/app/build.gradle.kts: no minSdk declared at all')
    if re.search(r'compileSdk\s*=\s*(\d+)', app):
        sdk = int(re.search(r'compileSdk\s*=\s*(\d+)', app).group(1))
        if sdk < 35:
            out.append(f'android/app/build.gradle.kts: compileSdk {sdk} — Play requires 35 for '
                       'new apps from August 2026 (see docs/PLAY_CHECKLIST.md)')
    return out


@check('P-21', 'R8 keeps what only the system can see',
       'With `isMinifyEnabled = true`, a receiver or service named only in the manifest is '
       'stripped, the APK still builds, and the feature is simply missing at runtime — the worst '
       'possible failure shape, because the release looks fine on every screen that has a test.')
def c_proguard():
    rules = raw('android/app/proguard-rules.pro')
    out = []
    if not rules.strip():
        return ['android/app/proguard-rules.pro: missing or empty while `isMinifyEnabled = true` '
                'in android/app/build.gradle.kts']
    for cls in ['TrackWidgetReceiver', 'FocusSessionService', 'flutterlocalnotifications', 'billingclient']:
        if cls not in rules:
            out.append(f'android/app/proguard-rules.pro: no keep rule mentioning `{cls}` — R8 can '
                       'remove it and the build will not tell you')
    body = raw('android/app/build.gradle.kts')
    if re.search(r'isMinifyEnabled\s*=\s*true', body) and 'proguard-rules.pro' not in body:
        out.append('android/app/build.gradle.kts: minification is on but proguard-rules.pro is '
                   'not applied to the release build type')
    return out


@check('P-22', 'the Glance widget depends only on artifacts the module declares',
       'Glance is pulled in explicitly because the Flutter plugin does not export it '
       'transitively. Importing a Glance sub-artifact that is not declared produces a host-side '
       'crash at widget-draw time, which no Dart test can see.')
def c_glance_deps():
    gradle = raw('android/app/build.gradle.kts')
    out = []
    kt = ''
    if KT_DIR.exists():
        kt = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in KT_DIR.rglob('*.kt'))
    # Package → artifact, for the subset Glance actually splits. `androidx.glance.state`, `.layout`
    # and `.id` are in the *core* `androidx.glance:glance` artifact, which `glance-appwidget`
    # brings in transitively — demanding a declaration for those would be noise, and a check that
    # cries wolf here gets deleted wholesale the next time somebody tidies this file.
    for pkg, artifact in [('androidx.glance.appwidget.', 'androidx.glance:glance-appwidget'),
                          ('androidx.glance.material3.', 'androidx.glance:glance-material3')]:
        if f'import {pkg}' in kt and artifact not in gradle:
            out.append(f'android/app/build.gradle.kts: host sources import {pkg}* but '
                       f'`{artifact}` is not declared — the widget then fails to inflate, in '
                       'release and in debug alike, and no Dart test can see it')
    return out

@check('P-23', 'AppState is provided once and read from the tree',
       'A second `AppState()` in a screen is a second database and a second billing listener, '
       'and a UI that never updates. The provider was moved above the app for this reason.')
def c_provider_once():
    out = require('lib/main.dart', 'ChangeNotifierProvider<AppState>.value',
                  'the single registration of the app state above the tree')
    for rel in dart_rel('lib'):
        if rel in ('lib/main.dart', 'lib/state/app_state.dart'):
            continue
        if re.search(r'\bAppState\(', code(rel)):
            out.append(f'{rel}: constructs an `AppState` directly instead of reading the provider')
    users = sum(1 for rel in dart_rel('lib') if re.search(r'context\.(watch|read)<AppState>', code(rel)))
    if users < 5:
        out.append(f'lib/: only {users} file(s) read AppState through the provider — the '
                   'single-source-of-truth wiring has been bypassed somewhere')
    return out


@check('P-24', 'what a class subscribes to, it unsubscribes from',
       'A listener added without a counterpart in dispose leaks the object it points at, keeps '
       'notifyListeners() painting a dead widget, and outlives the account it was built for.')
def c_listener_symmetry():
    out = []
    for rel in dart_rel('lib'):
        body = code(rel)
        added = len(re.findall(r'\.addListener\(', body))
        removed = len(re.findall(r'\.removeListener\(', body))
        if added > removed:
            out.append(f'{rel}: {added} `addListener(` vs {removed} `removeListener(` — the '
                       'difference is a listener nobody can remove')
    return out


@check('P-25', 'the billing stream subscription is cancellable and guarded',
       '`updates` is a broadcast stream that never ends. Held past dispose it keeps a dead '
       'AppState alive and lets a late event mutate it, which in debug is an assertion and in '
       'release is a zombie.')
def c_billing_subscription_cancellable():
    rel = 'lib/state/app_state.dart'
    body = code(rel)
    out = []
    if re.search(r'updates\.listen\(', body) and 'StreamSubscription' not in body:
        out.append(f'{rel}: the billing stream is listened to but the subscription is never held, '
                   'so it can never be cancelled')
    m = re.search(r'void dispose\(\) \{(.*?)\n  \}', body, re.S)
    if 'updates.listen(' in body and not m:
        return [f'{rel}: AppState subscribes to billing and to a ChangeNotifier but defines no '
                'dispose() — both outlive the object that owns them']
    if m:
        d = m.group(1)
        if '.cancel()' not in d:
            out.append(f'{rel}: `dispose()` does not cancel the billing subscription')
        if 'removeListener' not in d:
            out.append(f'{rel}: `dispose()` does not remove the billing listener')
        if 'super.dispose()' not in d:
            out.append(f'{rel}: `dispose()` does not call `super.dispose()` — ChangeNotifier '
                       'asserts it was disposed, so every later notifyListeners() throws')
    if 'updates.listen(' in body and '_disposed' not in body:
        out.append(f'{rel}: a stream callback mutates state with no `_disposed` guard')
    if '_disposed = true' in body and not re.search(r'if \(_disposed\)', body):
        out.append(f'{rel}: the disposed flag is set but never consulted before a late update '
                   'touches state')
    return out


@check('P-26', 'scheduling happens after the notifier is alive',
       'Reordering these two awaits turns every reminder into a silent no-op, and the only '
       'evidence is tomorrow morning. Same for a focus schedule, which needs the local-timezone '
       'database before AlarmManager will accept a zoned schedule at all.')
def c_init_order():
    rel = 'lib/main.dart'
    body = code(rel)
    i, j = body.find('notifications.init()'), body.find('await state.load()')
    if i < 0 or j < 0:
        return [f'{rel}: the init/load pair this check orders is not both present — re-derive the '
                'rule instead of deleting it']
    out = []
    if i > j:
        out.append(f'{rel}: `state.load()` is awaited before `notifications.init()`, so the '
                   'reminder sync inside load() runs against an uninitialized plugin and every '
                   'schedule is dropped without an error to show')
    if 'syncFocusSchedules' not in code('lib/state/app_state.dart'):
        out.append('lib/state/app_state.dart: `syncReminders()` no longer re-arms focus '
                   'schedules, so a reboot loses every future nudge until the user opens a timer')
    return out


@check('P-27', 'day arithmetic is calendar arithmetic',
       'A day is not 24 hours. `DateTime.now().subtract(Duration(days: 1))` lands on 23 hours '
       'across a spring-forward boundary, and any 24-hour division then truncates it to "the same '
       'day": streaks, history windows and habit rates all quietly lose a day, in November in '
       'India and in March in Europe.')
def c_calendar_math():
    # day_key.dart owns the one implementation of "what day is it", so it is exempt by
    # construction. Focus/health windows that compare *instants* are not day keys; anchoring on
    # `dayKey(` is what keeps those legitimate uses from false-positiving.
    # `test/` is scanned too: a fixture that builds its day keys from 24-hour blocks can put
    # two rows on the same key across a spring-forward day, which is a test failure that
    # only reproduces in a timezone the author does not live in.
    where = [(r, 'a day key derived from a fixed-duration shift')
             for r in dart_rel('lib') + dart_rel('test')
             if r != 'lib/util/day_key.dart']
    out = ban(r'dayKey\(\s*DateTime\.now\(\)\s*\.(?:subtract|add)\(\s*(?:const\s+)?Duration', where,
              'a day key made from a fixed-duration shift instead of `dayKeyFromToday()`')
    out += ban(r'dayKey\([^)\n]*\.subtract\(\s*(?:const\s+)?Duration\(days:', where,
               'a day key made by subtracting hours from a date')
    if 'daysBetween(' in code('lib/data/entry_repository.dart'):
        out.append('lib/data/entry_repository.dart: a second day-count implementation — '
                   '`daysBetweenKeys` in lib/util/day_key.dart is the single calendar rule')
    if re.search(r'Future<int>\s+streakOf', code('lib/data/entry_repository.dart')):
        out.append('lib/data/entry_repository.dart: a second streak rule '
                   '(`AppState.streak` is the one rule the whole UI reads)')
    return out


@check('P-28', 'extension methods are imported or not used',
       'This repo had two `firstOrNull` call sites written against an extension that was never '
       'imported: it lives in package:collection, which is only a transitive dependency here. '
       'The analyzer sees a compile error; a code review sees idiomatic Dart.')
def c_unimported_extensions():
    out = []
    names = r'firstOrNull|lastOrNull|singleOrNull|firstWhereOrNull|elementAtOrNull|mapOrNull|sortedDescending'
    for rel in dart_rel('lib'):
        body = code(rel)
        m = re.search(r'\.' + names + r'\b', body)
        if m and not re.search(r"import\s+'package:collection/collection\.dart'", body):
            out.append(f'{rel}:{body[:m.start()].count(chr(10)) + 1}: `{m.group(0).lstrip(".")}` is '
                       'a package:collection extension and that import is not in this file '
                       '(dart:core does not declare it)')
    return out


@check('P-29', 'a focus session never claims enforcement it did not observe',
       'The honest states are timer-only, armed, unavailable and lost. `verified` requires the '
       'foreground-app detector to have reported events; a claim that apps were blocked when '
       'nothing was blocking them is the one thing this feature must never do, because the user '
       'cannot check it from the inside.')
def c_focus_honesty():
    rel = 'lib/data/focus_engine.dart'
    fn = body_of(rel, 'static FocusEnforcement enforcementFor(')
    if fn is None:
        return [f'{rel}: `enforcementFor` is not readable in the shape this check needs — '
                're-derive the rule, do not delete it']
    out = []
    if 'FocusEnforcement.timerOnly' not in fn:
        out.append(f'{rel}: a session that never asked to block no longer answers `timerOnly`, so '
                   'it falls through to a state implying enforcement was attempted')
    if 'detectionEvents > 0' not in fn or 'FocusEnforcement.verified' not in fn:
        out.append(f'{rel}: `verified` is no longer gated on the detector reporting events — that '
                   'one expression is the entire honesty of Focus Lock')
    i_lost, i_verified = fn.find('FocusEnforcement.lost'), fn.find('FocusEnforcement.verified')
    if i_lost >= 0 and i_verified >= 0 and i_lost > i_verified:
        out.append(f'{rel}: the `lost` branch now runs after `verified`, so one stray detection '
                   'event outranks the fact that the service died')
    if re.search(r'detectionEvents\s*>=\s*0', fn):
        out.append(f'{rel}: `detectionEvents >= 0` cannot fail, so it is not evidence')
    ob = body_of(rel, 'static FocusOutcome outcomeFor(')
    if ob is None:
        out.append(f'{rel}: `outcomeFor` is unreadable in the shape this check needs')
    elif 'completed' in ob and 'enforcement' not in ob and 'isConfirmed' not in ob:
        out.append(f'{rel}: `outcomeFor` no longer consults enforcement before calling a session '
                   'complete — a blocking session whose enforcement was never confirmed must '
                   'degrade, not pass')
    return out

@check('P-30', 'focus outcomes are decided by the engine, not by the store',
       'A row whose persistence layer writes its own `completed` outcome is a session that '
       'succeeded because the code said so.')
def c_focus_outcome_owner():
    rel = 'lib/data/focus_repository.dart'
    body = code(rel)
    out = []
    if 'outcomeFor(' not in body:
        out.append(f'{rel}: the repository no longer asks the engine for the outcome, so whatever '
                   'it writes instead is a claim')
    if re.search(r'outcome:\s*FocusOutcome\.completed\b', body):
        out.append(f'{rel}: a hardcoded `FocusOutcome.completed` assignment — completion must '
                   'come from elapsed >= target and confirmed enforcement')
    return out


@check('P-31', 'the notification tap route exists',
       'A reminder that opens the wrong screen is worse than one that does nothing: the user sees '
       'the app react and is taken somewhere unrelated, and now distrusts the reminder.')
def c_reminder_route():
    if 'pendingNotificationPayload' not in code('lib/screens/home_shell.dart'):
        return ['lib/screens/home_shell.dart: nothing consumes `pendingNotificationPayload`, so a '
                'reminder tap opens the app and goes nowhere']
    return []


# ======================================================================================
# P-32 .. P-51 — cohesion pins.
#
# These are the checks `tools/gate_probe.py` breaks on purpose. Each names the exact code it
# pins, and that is deliberate: the pin IS the value, because these are the lines a future
# "simplification" removes first. Where a rule generalises (no force-unwrap of a projection)
# the general form is checked too, so the check is not merely a fingerprint.
# ======================================================================================

@check('P-32', 'a projection read is never force-unwrapped',
       'The series projections are Maps keyed by tracker id. `!` on an id the projection does not '
       'carry throws while the frame is building, which is a white screen rather than a caught error.')
def c32():
    out = require('lib/screens/detail_screen.dart', 'final hist = state.historyOf(trackerId);',
                  'the guarded history read in the detail screen')
    where = [(r, 'force-unwrap of a state projection')
             for r in dart_rel('lib/screens') + dart_rel('lib/widgets')
             if re.search(r'state\.(history|rhythm|byId)\[[^\]]{1,40}\]\s*!', code(r))]
    return out + ban(r'state\.(history|rhythm|byId)\[[^\]]{1,40}\]\s*!', where,
                     'a `!` on a projection read — `historyOf(id)` returns an empty list instead '
                     'of throwing on a tracker the projection does not carry')


@check('P-33', 'a series is guarded before `.last`',
       'On a fresh install every series is empty. `.last` on one throws inside the card build, and '
       'this is the first screen anybody ever sees.')
def c33():
    return require('lib/widgets/tracker_card.dart', 'final v = values.isEmpty ? 0.0 : values.last;',
                   'the emptiness guard in the tracker row') + require(
        'lib/widgets/tracker_card.dart', 'final v = widget.values.isEmpty ? 0.0 : widget.values.last;',
        'the emptiness guard in the hero card (which reads widget.values, not values)')


@check('P-34', 'a row opens what its label says',
       'Two rows in this app were labelled "Goals"/"Trackers" and called setTab() to an unrelated '
       'tab instead of opening the sheet they described. A tab index is a number; the sheet is the '
       'contract the label made.')
def c34():
    return require('lib/screens/trackers_screen.dart', 'openGoalsSheet(context)',
                   'the Goals row opening the goals sheet') + ban(
        r'setTab\(', [('lib/screens/trackers_screen.dart', 'a tab switch where a sheet belongs')],
        'this screen has no business moving the user to another tab')


@check('P-35', 'a settings row that edits a tracker edits it',
       'Same defect class as P-34, in the row that carried `openGoalSheet(context, t)`.')
def c35():
    return require('lib/screens/settings_screen.dart', 'openGoalSheet(context, t)',
                   'the per-tracker goal row opening the goal sheet for that tracker') + ban(
        r'setTab\(2\)', [('lib/screens/settings_screen.dart', 'a tab switch that replaced the sheet')],
        'Momentum is not where a goal is edited')


@check('P-36', 'a sheet pops after its write is known to have landed',
       'Popping first destroys the context the failure toast needs, so a refused write looks '
       'exactly like a successful one — which is the one outcome a logging UI must never produce.')
def c36():
    rel = 'lib/screens/log_sheets.dart'
    body = code(rel)
    m = re.search(r'return SubmitOnce\(\s*onSubmit: \(\) async \{(.*?)\n    \},', body, re.S)
    if not m:
        return [f'{rel}: `_sheetAction` no longer wraps a SubmitOnce whose body this check can '
                'read; the write/pop ordering it pins is exactly what a refactor regresses']
    block = m.group(1)
    w, p = block.find('if (!write())'), block.find('Navigator.of(context).pop()')
    if w < 0:
        return [f'{rel}: the save path no longer consults the write result at all, so every '
                'failure becomes a success message']
    if p >= 0 and p < w:
        return [f'{rel}: the sheet pops before `write()` runs — a refused value would be reported '
                'as logged']
    if 'return false;' not in block:
        return [f'{rel}: `_sheetAction` no longer returns false on a refused write, so SubmitOnce '
                're-enables a button whose sheet stayed open for no reason']
    return []


@check('P-37', 'a failed write is visible outside the sheet that made it',
       'The repository refuses values out of range. A refusal that only prints in the sheet that '
       'triggered it is a refusal the user never sees, which is a silent failure with extra steps.')
def c37():
    out = require('lib/state/app_state.dart', 'SaveFailure? writeFailure;',
                  'the field that carries the last refused write')
    out += require('lib/screens/home_shell.dart', 'writeFailure',
                   'the snackbar that reads it back to the user')
    return out


@check('P-38', 'a one-shot action cannot be fired twice',
       'Play Billing dedupes nothing. Two taps on "Start trial" is two purchase attempts and at '
       'least one user-visible error, and the second tap is free on a phone.')
def c38():
    out = require('lib/widgets/glass.dart', 'class SubmitOnce extends StatefulWidget {',
                  'the button that disables itself while an action is in flight')
    users = [r for r in dart_rel('lib') if 'SubmitOnce(' in code(r)]
    if len(users) < 2:
        out.append(f'lib/: SubmitOnce is used by {len(users)} file(s); the sheets that write to '
                   'billing and to the database should be wrapped in it')
    return out


@check('P-39', 'a past day can be corrected',
       'The day-level edit is what makes a mis-tap recoverable. Removing it strands the user with '
       'an increment-only history, which is a history they cannot trust.')
def c39():
    return require('lib/state/app_state.dart', 'Future<bool> setDayValue(',
                   'the day-edit path in the state layer') + \
        require('lib/data/entry_repository.dart', 'Future<bool> setDayValue(',
                'the persistence half of the day edit')


@check('P-40', 'a day can be deleted, whatever wrote it',
       'The day-level delete was half-implemented once already, as a cache mutation with no SQL — '
       'the number came back after a restart. The other half of the same bug: it deleted manual '
       'rows only, so a cleared day resurrected its imported health row.')
def c40():
    out = require('lib/state/app_state.dart', 'Future<int?> clearDay(', 'the day-delete path') + \
        require('lib/data/entry_repository.dart', 'Future<int> clearDay(',
                'the SQL half of the day delete') + \
        require('lib/data/db/database.dart', 'deleteDailyForAllSources',
                'the DAO deletion that clears a day for every source, not just manual ones')
    m = re.search(r'Future<int> clearDay\((.*?)\n  \}', code('lib/data/entry_repository.dart'), re.S)
    if m and m.group(1).count('_clearSlot') > 1:
        out.append('lib/data/entry_repository.dart: `clearDay` writes the day cache twice, which '
                   'is how a cleared day came back with the old number')
    return out


@check('P-41', 'history reads its own rows, not the 60-day projection',
       '`historyDays` used to return the cached 60-day series, so a Pro user who imported three '
       'years of data scrolled to the end of their own history and found nothing.')
def c41():
    out = require('lib/state/app_state.dart', 'Future<List<RecordedDay>> recordedDays(',
                  'the SQL-backed history page (every day actually logged)')
    out += require('lib/screens/detail_screen.dart', 'state.recordedDays(',
                   'the history list reading through it')
    out += ban(r'state\.historyOf\([^)\n]*\)\.reversed',
               [('lib/screens/detail_screen.dart', 'history built from the projection')],
               'the 60-day cache is not the history')
    return out


@check('P-42', 'no top-level name is declared twice, in a file or across the import graph',
       'A duplicate class in one file is the shape of the bug this repo shipped in the billing '
       'seam: two `PurchaseVerifier` declarations, different signatures, both "used", neither '
       'matching the other. The analyzer reports it; this catches it in a tree nobody has run the '
       'analyzer on yet.')
def c42():
    out = []
    # A top-level declaration starts at column 0 — anything indented is inside a class.
    decl = re.compile(r'^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*'
                      r'(?:class|mixin|enum|extension|typedef)\s+([A-Za-z_$][\w$]*)', re.M)
    fun = re.compile(r'^(?:[A-Za-z_$][\w$<>,? .]*?\s+)?([A-Za-z_$][\w$]*)\s*(?:<[^>\n]*>)?\s*\(', re.M)
    getter = re.compile(r'^[A-Za-z_$][\w$<>,? .]*?\s+get\s+([A-Za-z_$][\w$]*)', re.M)
    skip = {'if', 'for', 'while', 'switch', 'return', 'else', 'case', 'do', 'try', 'await',
            'async', 'get', 'set', 'static', 'const', 'final', 'factory', 'new', 'late', 'var'}
    where: dict[str, list[str]] = {}
    for rel in dart_rel('lib'):
        body = code(rel)
        counts: dict[str, int] = {}
        for rx in (decl, fun, getter):
            for mm in rx.finditer(body):
                nm = mm.group(1)
                if nm.startswith('_') or nm in skip:
                    continue
                counts[nm] = counts.get(nm, 0) + 1
                where.setdefault(nm, []).append(rel)
        for nm, n in sorted(counts.items()):
            if n > 1:
                out.append(f'{rel}: `{nm}` is declared {n} times at the top level of one file — '
                           'the second is always a stale copy, and Dart will not compile two')

    # Two files, same name: legal on its own, and an error the moment anything imports both —
    # which is precisely how `int dayKey(DateTime)` in `util/format.dart` would break the app
    # while both files compiled happily on their own. So the question is reachability, and the
    # import graph is what answers it. Private names are exempt: they cannot collide.
    imports: dict[str, set[str]] = {}
    for rel in dart_rel('lib'):
        targets = set()
        for mm in re.finditer(r"^\s*(?:import|export)\s+'([^']+)'", raw(rel), re.M):
            t = mm.group(1)
            if t.startswith('package:track/'):
                targets.add('lib/' + t[len('package:track/'):])
            elif t.startswith('package:'):
                continue  # a pub package cannot collide with a local top-level name
            else:
                base = (ROOT / rel).parent / t
                try:
                    targets.add(str(base.resolve().relative_to(ROOT)))
                except ValueError:
                    continue
        imports[rel] = {t for t in targets if t in where or (ROOT / t).exists()}

    def closure(rel: str) -> set[str]:
        seen, stack = set(), [rel]
        while stack:
            cur = stack.pop()
            for dep in imports.get(cur, ()):  # cycle-safe: `seen` gates every push
                if dep not in seen:
                    seen.add(dep)
                    stack.append(dep)
        return seen

    scopes = {rel: closure(rel) | {rel} for rel in dart_rel('lib')}
    for nm, files in sorted(where.items()):
        distinct = sorted(set(files))
        if len(distinct) < 2:
            continue
        clash = [sc for sc, vis in scopes.items() if len([f for f in distinct if f in vis]) > 1]
        if clash:
            out.append(f'`{nm}` is declared in {", ".join(distinct)} and {len(clash)} file(s) '
                       f'import enough of both to see them together (e.g. {clash[0]}) — an '
                       'ambiguous import, and a hard error at the first use')
    return out

@check('P-43', 'a wipe reaches every store',
       '`reset()` clearing the tracker tables while routines and focus sessions kept their rows '
       'leaves data on disk with no UI that can show it or delete it — the worst outcome for a '
       'function whose entire job is deletion.')
def c43():
    body = code('lib/state/app_state.dart')
    m = re.search(r'Future<Map<String, int>> reset\(\) async \{(.*?)\n  \}', body, re.S)
    if not m:
        return ['lib/state/app_state.dart: `reset()` is no longer a `Future<Map<String, int>>` '
                'returning the rows it removed — see P-44, which is the same defect from the other '
                'direction']
    block = m.group(1)
    out = []
    for call, why in [
        ('repo.deleteAllUserData()', 'tracker rows survive a wipe of the account'),
        ('commitmentRepo.deleteAllUserData()', 'routines survive a wipe of the account'),
        ('focusRepo?.deleteAllUserData(', 'focus sessions survive a wipe of the account'),
    ]:
        if call not in block:
            out.append(f'lib/state/app_state.dart: `reset()` no longer calls `{call}` — {why}')
    if 'focusRepo?.deleteAllUserData(' in block and 'keepDefinitions: false' not in block:
        out.append('lib/state/app_state.dart: the focus wipe keeps the user\'s saved rule sets '
                   'while the tracker and routine wipes do not, so "delete my data" half-deletes')
    return out


@check('P-44', 'a wipe reports what it removed',
       'The confirmation dialog promises to name the counts. A `Future<void>` reset cannot keep '
       'that promise, and "your data was deleted" is not information a user can act on.')
def c44():
    return require('lib/state/app_state.dart', 'Future<Map<String, int>> reset() async',
                   'the counts the confirmation sheet reports back')


@check('P-45', 'every DAO wipe deletes its own tables',
       'Same defect as P-43 one layer down: the DAO owns the SQL, and a table missing from its '
       'wipe is a table no code path can ever clear.')
def c45():
    body = code('lib/data/db/database.dart')
    # `commitmentRows` is guarded by the `keepDefinitions` argument, and that guard is the
    # documented contract rather than an omission.
    wipes = re.findall(r'Future<Map<String, int>> deleteAllUserData\([^)]*\) async \{(.*?)\n  \}',
                       body, re.S)
    out = []
    if len(wipes) < 2:
        out.append(f'lib/data/db/database.dart: only {len(wipes)} readable `deleteAllUserData` '
                   'wipe(s) — the routine and focus DAOs must each keep their own, and this check '
                   'is what notices one being folded away')
    joined = '\n'.join(wipes)
    for tbl, why in [('commitmentEntries', 'routine day records'),
                     ('commitmentPauses', 'routine pause records'),
                     ('focusSessions', 'focus sessions')]:
        if f'delete({tbl})' not in joined:
            out.append(f'lib/data/db/database.dart: no wipe calls `delete({tbl})` — {why} are left '
                       'behind by every path that promised to empty them')
    return out


@check('P-46', 'an increment is validated by its result, not by its sign',
       'The hero card\'s swipe-left is a negative delta. Validating a *delta* with the value '
       'validator refused every decrement, and the event row kept the requested delta while the '
       'rollup kept the clamped total — so the feed described a change the day\'s number does not '
       'contain.')
def c46():
    m = re.search(r'bool logAdd\(String id, double delta[^\n]*\n(.*?)\n  \}',
                  code('lib/state/app_state.dart'), re.S)
    if not m:
        return ['lib/state/app_state.dart: `logAdd` is not in a shape this check can read — '
                're-derive the rule, do not delete it']
    fn = m.group(1)
    out = []
    if re.search(r'ValueValidation\.sanitize\(\s*\w+,\s*delta\s*\)', fn):
        out.append('lib/state/app_state.dart: `logAdd` sanitizes the delta itself, which rejects '
                   'every negative value — the decrement gesture becomes a no-op')
    if re.search(r'addEvent\([^,]+,\s*delta\s*,', fn):
        out.append('lib/state/app_state.dart: `logAdd` persists the *requested* delta rather than '
                   'the change actually applied to the rollup')
    if 'trackerOrNull' not in fn:
        out.append('lib/state/app_state.dart: `logAdd` writes to a tracker it has not looked up, '
                   'so an unknown id either throws or paints the cache for something that does '
                   'not exist')
    return out


@check('P-47', 'every write path returns whether it wrote',
       'Every sheet that logs a value has to be able to say "nothing was saved". A `void` write '
       'plus an ignored result in the UI is how an invalid entry became a success message.')
def c47():
    out = []
    state = code('lib/state/app_state.dart')
    if re.search(r'\bvoid addExpense\(', state):
        out.append('lib/state/app_state.dart: `addExpense` returns void, so the sheet cannot tell '
                   'a refusal from a save')
    repo = code('lib/data/entry_repository.dart')
    for sig in re.finditer(r'\bFuture<void>\s+(add\w+|set\w+|clearDay)\(', repo):
        out.append(f'lib/data/entry_repository.dart: `{sig.group(1)}` returns Future<void>, so a '
                   'refusal cannot be seen by its caller')
    ui = code('lib/screens/log_sheets.dart')
    if re.search(r'write: \(\) => state\.addExpense\([^)]*\),', ui) and 'bool addExpense' not in state:
        out.append('lib/screens/log_sheets.dart: the expense sheet returns a void call from a '
                   '`bool Function()` — it cannot compile, which is the good outcome, and the bad '
                   'outcome is a `write:` that always says true')
    return out


@check('P-48', 'one definition per shared metric',
       'Average and streak were each computed twice, in two files, with two rules: a day-window '
       'average in the DAO and a rolling one in the repository, feeding different widgets. The UI '
       'then showed two numbers for one week, and both were right.')
def c48():
    out = []
    dao, repo = code('lib/data/db/database.dart'), code('lib/data/entry_repository.dart')
    for sig, why in [
        (r'Future<double>\s+averageOfLast', 'a second owner of "average of the last N days"'),
        (r'Future<int>\s+qualifiedDaysDesc', 'a second streak-shaped query'),
        (r'Future<List<DailyEntry>>\s+watchSeries', 'a series stream the repository already owns'),
    ]:
        if re.search(sig, dao):
            out.append(f'lib/data/db/database.dart: `{re.search(sig, dao).group(0).strip()}` is '
                       f'{why} — one rule, in one file')
    if re.search(r'\bdouble average\(', repo):
        out.append('lib/data/entry_repository.dart: `average()` duplicates `windowAverage`; the '
                   'two were both described as "your week" in different widgets')
    return out


@check('P-49', 'the rhythm panel loads its own data',
       'The hour-of-day panel read a cache field that no code ever wrote. It rendered "not '
       'computed yet" forever, in the exact shape a half-finished feature has when nobody has run '
       'it, and the repository query that could fill it had no caller at all.')
def c49():
    out = []
    state = code('lib/state/app_state.dart')
    if 'Future<RhythmBuckets>' in str(state) or 'refreshRhythm' not in state:
        out.append('lib/state/app_state.dart: nothing fills `_rhythms`, so the panel can only ever '
                   'render its empty state')
    ui = code('lib/screens/detail_screen.dart')
    if '_RhythmList' in ui and 'refreshRhythm' not in ui:
        out.append('lib/screens/detail_screen.dart: the rhythm panel reads without loading')
    if '_RhythmList' in ui and 'hasData' not in ui:
        out.append('lib/screens/detail_screen.dart: the rhythm panel no longer distinguishes "no '
                   'events" from "not loaded", so an empty day looks like a broken feature')
    repo = code('lib/data/entry_repository.dart')
    if re.search(r'const width = 24 ~/ buckets', repo):
        out.append('lib/data/entry_repository.dart: the rhythm bucket width divides 24 by a '
                   'runtime count and drops the remainder, so the last bar stops short of midnight')
    return out


@check('P-50', 'minutes and goals are rounded once, from the stored value',
       'The minutes formatter divided a raw double for the hour and rounded it for the minute, so '
       '59.5 minutes of screen time rendered as `0m`. The goal line truncated an un-rounded goal, '
       'so a 90.6-minute limit said "1h limit" next to a day reading "1h 31m".')
def c50():
    rel = 'lib/util/format.dart'
    fmt, body = code(rel), raw(rel)
    out = []
    if body.count('final total = v.round();') < 2:
        out.append(f'{rel}: the minutes formatter no longer rounds once before splitting — '
                   '`v ~/ 60` on 0.992 minutes prints "0m" (fmtValue and fmtCompact each must)')
    if re.search(r'\b(?:const )?(?:int|double) h = v ~/ 60|double h = v / 60', fmt):
        out.append(f'{rel}: a minutes split was changed back to dividing the raw value')
    if 't.goal.round() ~/ 60' not in body:
        out.append(f'{rel}: the goal line no longer rounds the goal before converting to hours')
    m = re.search(r'double activityScore\((.*?)\n  \}', body, re.S)
    if not m:
        out.append(f'{rel}: `activityScore` is unreadable in the shape this check needs')
    elif 'v > 0' not in m.group(1):
        out.append(f'{rel}: `activityScore` credits a period without checking that anything was '
                   'recorded in it — a user who logged nothing still earned consistency points')
    return out


@check('P-51', 'a cycle prediction needs a usable sample',
       'The cycle widget predicted "period due today" whenever it had two periods logged, and two '
       'periods thirty years apart are two data points of nothing. `hasPrediction` is the gate the '
       'UI is allowed to trust, so it has to mean "usable", not merely "non-empty".')
def c51():
    rel = 'lib/data/cycle_stats.dart'
    body = code(rel)
    out = []
    m = re.search(r'bool get hasPrediction\s*=>\s*([^;]+);', body)
    if not m:
        return [f'{rel}: `hasPrediction` is no longer a readable predicate — re-derive this check; '
                'deleting it reopens the gate the UI depends on']
    if 'shortestLength' not in m.group(1) or 'starts.length' not in m.group(1):
        out.append(f'{rel}: `hasPrediction` no longer excludes an unusable sample, so a 30-year '
                   'gap between two logs becomes a prediction')
    # The rule is that the two "no prediction" reasons are told apart, because they ask the
    # user for opposite things: one has not logged a second period yet, the other has and is
    # unusable. Phrasing is free, the distinction is not — so this reads the branch instead of
    # asserting one phrase. (It asserted the phrase, and thereby blocked the copy fix that made
    # the line accurate for gaps that are too *short* as well as too long. `gate_probe.py` P-51
    # still fires, because it edits `hasPrediction`, which is the thing being pinned.)
    sb = body_of(rel, 'String get summary', mode='prose')
    if sb is None:
        out.append(f'{rel}: `summary` is unreadable in the shape this check needs')
    elif 'starts.length < 2' not in sb:
        out.append(f'{rel}: `summary` no longer separates "not enough periods logged" from '
                   '"the gaps are unusable", which is the difference between telling somebody to '
                   'log more and telling them their data cannot support a guess')
    elif 'guess' not in sb:
        out.append(f'{rel}: the unusable-gap line no longer says a prediction would be a guess')
    return out


# --------------------------------------------------------------------------------------
# runner
# --------------------------------------------------------------------------------------

def run() -> int:
    if VERBOSE:
        for cid, title, explains, _fn in CHECKS:
            print(f'{cid}  {title}')
            if explains:
                print('      ' + explains.replace('\n', '\n      '))
        print(f'\n{len(CHECKS)} checks. Text and structure only: this gate cannot prove a type '
              'is right, that a query returns the rows it should, or that the app does what a '
              'user expects. `flutter analyze`, `flutter test` and the manual checklist in '
              'docs/RELEASE.md cover those, and a clean run here is not a release approval.')
        return 0

    problems, fired = 0, []
    for cid, title, _explains, fn in CHECKS:
        try:
            found = [x for x in fn() if x]
        except Exception as e:  # a gate that crashes must never read as "clean"
            found = [f'check raised {type(e).__name__}: {e} — the gate cannot certify what it '
                     'could not evaluate; fix the check']
        if found:
            problems += len(found)
            fired.append(cid)
            print(f'FAIL  {cid}  {title}')
            for f in found:
                print(f'        {f}')
    print()
    if problems:
        print(f'release gate: {problems} problem(s) in {len(fired)} check(s) ({", ".join(fired)}) '
              f'— {len(CHECKS)} checks run')
        return 1
    print(f'release gate: clean — {len(CHECKS)} checks, 0 problems (text/structure rules only; not '
          'a substitute for `flutter analyze` or `flutter test`)')
    return 0


if __name__ == '__main__':
    raise SystemExit(run())
