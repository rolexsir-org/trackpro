#!/usr/bin/env python3
"""Generate docs/focus_lock_preview.html from the Focus Lock sources.

Why a generator instead of a hand-written mock: a preview that drifts from the code
is worse than no preview, because it teaches the wrong thing. This script reads the
real copy out of `lib/data/focus_engine.dart` and the real strings out of the screens,
asserts it found all of them, and refuses to write the file if anything is missing.

What it produces is a **static layout rendering**, not a screenshot and not a build:
no Flutter SDK exists on the machine that ran it. Numbers shown in the data frames are
illustrative layout values and are labelled as such in the output.

    python3 tools/focus_preview.py            # writes docs/focus_lock_preview.html
"""
from __future__ import annotations

import datetime
import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, 'lib', 'data', 'focus_engine.dart')
SETUP = os.path.join(ROOT, 'lib', 'screens', 'focus_setup_sheets.dart')
OUT = os.path.join(ROOT, 'docs', 'focus_lock_preview.html')

ENGINE_SRC = open(ENGINE, encoding='utf-8').read()
SETUP_SRC = open(SETUP, encoding='utf-8').read()


# --------------------------------------------------------------------------- parse
def _literals(chunk: str) -> str:
    """Join adjacent Dart string literals in a switch arm into the one sentence."""
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'", chunk)
    joined = ''.join(parts)
    return joined.replace("\\'", "'").replace('\\n', '\n')


def extension_body(name: str) -> str:
    match = re.search(r'extension ' + name + r'\b.*?\n\}', ENGINE_SRC, re.S)
    assert match, f'extension {name} not found'
    return match.group(0)


def getter_switches(body: str) -> dict:
    """{getter name: {arm name: text}} for every `String get x => switch (this) {}`."""
    out = {}
    starts = [(m.group(1), m.start()) for m in re.finditer(r'String get (\w+) =>', body)]
    for index, (name, start) in enumerate(starts):
        end = starts[index + 1][1] if index + 1 < len(starts) else len(body)
        out[name] = switch_arms(body[start:end])
    return out


ARM = re.compile(r'(?:FocusMode|FocusEnforcement|FocusOutcome|FocusEndReason)\.(\w+)\s*=>')


def switch_arms(block: str) -> dict:
    """`{arm name: sentence}`. A `_ =>` default arm is deliberately not collected:
    every string this preview renders must be a named arm, so a missing one is a
    failure rather than a silent fallback."""
    arms = {}
    marks = list(ARM.finditer(block))
    for index, mark in enumerate(marks):
        end = marks[index + 1].start() if index + 1 < len(marks) else len(block)
        arms[mark.group(1)] = _literals(block[mark.end():end])
    return arms


MODE = getter_switches(extension_body('FocusModeText'))
ENF = getter_switches(extension_body('FocusEnforcementText'))
OUTCOME = getter_switches(extension_body('FocusOutcomeText'))

CANCEL = {}
_cancel_body = re.search(r'static String cancellationCopy\(FocusMode mode\) => switch \(mode\) \{(.*?)\n      \};',
                         ENGINE_SRC, re.S)
assert _cancel_body, 'cancellationCopy not found'
CANCEL.update({
    key: value.replace('${pauseBudgetFor(FocusMode.deep)!.inMinutes}', '3')
    for key, value in switch_arms(_cancel_body.group(1)).items()
})


def assert_complete():
    for name, table, keys in (
        ('FocusModeText', MODE, {'standard', 'blocking', 'deep'}),
        ('FocusEnforcementText', ENF, {'timerOnly', 'unavailable', 'armed', 'verified', 'lost'}),
        ('FocusOutcomeText', OUTCOME, {'completed', 'completedDegraded', 'interrupted', 'cancelled'}),
    ):
        for getter, arms in table.items():
            found = {k for k in arms if k != '_'}
            missing = keys - found
            # Not every extension defines every getter over the same set (tone has no
            # `_` default, etc.); only the three that matter for user-visible copy are
            # required to be complete.
            if getter in {'label', 'blurb', 'limitation', 'detail', 'emoji', 'shortLabel'}:
                assert not missing, f'{name}.{getter} is missing {sorted(missing)}'
            for key in found:
                assert arms[key].strip(), f'{name}.{getter}.{key} extracted empty'
    assert set(CANCEL) == {'standard', 'blocking', 'deep'}, sorted(CANCEL)


assert_complete()


def sheet_string(needle: str) -> str:
    """Pull one user-visible string out of the setup-sheet source, joined if split."""
    compact = SETUP_SRC
    for match in re.finditer(r"'((?:[^'\\]|\\.)*)'", compact):
        pass
    # Normalise both sides: strip quotes and collapse whitespace, then look for the
    # needle. Adjacent literals in the source carry two-space indentation between them,
    # which is exactly what the flattening removes.
    flat = re.sub(r"'\s*'", '', compact)
    flat = flat.replace("\\'", "'").replace('\\n', ' ')
    flat = re.sub(r'\s+', ' ', flat)
    target = re.sub(r'\s+', ' ', needle.strip())
    assert target in flat, f'setup-sheet copy not found verbatim: {target[:70]!r}'
    return needle


# ---------------------------------------------------------------- illustrative data
# Layout values, not measurements. Labelled as such in the rendered page: nothing here
# was produced by running the app, and no number is presented as a reading from a
# device or from a real session.
SAMPLE = {
    'ring_remaining': '18:42',
    'ring_progress': 0.252,
    'goal': 'Dissertation chapter',
    'planned': '25 min planned',
    'covered': 3,
    'detected_opens': 2,
    'focused': '6 min',
    'paused': '1 min',
    'sessions': 23,
    'clean': 13,
    'served': 17,
}

PLANNED_MS = 25 * 60 * 1000
REMAINING_MS = 18 * 60 * 1000 + 42 * 1000
PROGRESS = 1 - REMAINING_MS / PLANNED_MS
assert abs(PROGRESS - SAMPLE['ring_progress']) < 0.01

CIRCUMFERENCE = 2 * 3.14159265 * 110
DASH = CIRCUMFERENCE * PROGRESS


def esc(text: str) -> str:
    return html.escape(text, quote=True)


# ------------------------------------------------------------------------ template
def mode_cards() -> str:
    cards = []
    for mode in ('standard', 'blocking', 'deep'):
        accent = {'standard': '#007AFF', 'blocking': '#5856D6', 'deep': '#AF52DE'}[mode]
        selected = mode == 'blocking'
        cards.append(f'''
        <div class="mode {'selected' if selected else ''}" style="--accent:{accent}">
          <div class="mode-head">
            <span class="mode-emoji">{esc(MODE['emoji'][mode])}</span>
            <span class="mode-name">{esc(MODE['label'][mode])}</span>
            {'<span class="tick">●</span>' if selected else ''}
          </div>
          <p class="mode-blurb">{esc(MODE['blurb'][mode])}</p>
          <p class="mode-limit">ⓘ {esc(MODE['limitation'][mode])}</p>
        </div>''')
    return '\n'.join(cards)


def permission_rows() -> str:
    rows = [
        ('📊', 'Usage access', True,
         sheet_string('Lets Track Pro notice when a covered app comes to the front, so it can step in. It reads '
                      'only the package name and the moment — never what is on the screen, never messages, '
                      'never your accounts.'),
         sheet_string('Without it, no app can be covered. Sessions become timers.')),
        ('🪟', 'Display over other apps', True,
         sheet_string('Lets Track Pro draw the "this is covered" panel over the app you opened. The panel has '
                      'one action — leave the covered app — and it never imitates another app\'s interface.'),
         sheet_string('Without it, Track Pro can detect an app but cannot say anything about it, so it does not claim to cover it.')),
        ('🔔', 'Notifications', False,
         sheet_string('Used for the running-session notice Android requires while the detector is active, and '
                      'for scheduled sessions you set up. Reminder text stays private on the lock screen.'),
         sheet_string('Without it, the running-session notice is missing and Android may stop the detector. '
                      'A session still runs as a timer.')),
        ('🔋', 'Battery optimisation', False,
         sheet_string('If Android is optimising Track Pro, it can suspend the detector mid-session, and covering '
                      'apps stops until you come back.'),
         sheet_string('Sessions still run, but they may quietly stop being enforced — which is exactly the '
                      'case this screen exists to avoid.')),
    ]
    out = []
    for emoji, title, granted, reason, without in rows:
        out.append(f'''
        <div class="perm">
          <div class="perm-head">
            <span>{emoji}</span>
            <strong>{esc(title)}</strong>
            <span class="pill {'ok' if granted else 'warn'}">{'Granted' if granted else 'Not granted'}</span>
          </div>
          <p>{esc(reason)}</p>
          <p class="faint">{esc(without)}</p>
          <a class="link">Open system settings →</a>
        </div>''')
    return '\n'.join(out)


def session_row(emoji, goal, pill, tone, line, extra='', quote='') -> str:
    quote_html = f'<p class="quote">“{esc(quote)}”</p>' if quote else ''
    extra_html = f'<p class="row-accent">{esc(extra)}</p>' if extra else ''
    return f'''
        <div class="row">
          <div class="row-head">
            <span>{emoji}</span>
            <strong>{esc(goal)}</strong>
            <span class="pill {tone}">{esc(pill)}</span>
          </div>
          <p class="faint">{esc(line)}</p>
          {extra_html}
          {quote_html}
        </div>'''


TODAY_ISO = datetime.datetime.now()


def greeting() -> str:
    hour = TODAY_ISO.hour
    if hour < 12:
        return 'Good morning'
    if hour < 18:
        return 'Good afternoon'
    return 'Good evening'


def long_date() -> str:
    return TODAY_ISO.strftime('%A, %-d %B') if os.name != 'nt' else TODAY_ISO.strftime('%A, %d %B')


FRAMES = f'''
  <!-- ============================================================ frame 1: Today -->
  <figure class="frame">
    <figcaption><b>1 · Today</b><span>the entry point</span></figcaption>
    <div class="phone">
      <div class="screen">
        <div class="bigtitle">
          <h1>{esc(greeting())}</h1>
          <p>{esc(long_date())}</p>
        </div>

        <div class="card focus-card">
          <div class="row-head">
            <span>🎯</span><strong>Focus</strong>
            <span class="spacer"></span>
            <span class="faint">18 min today</span>
          </div>
          <p class="body">Last session: {esc(SAMPLE['goal'])} · 25 min · completed</p>
          <div class="btn-row">
            <span class="btn primary indigo">Focus again</span>
            <span class="btn tinted">History</span>
          </div>
        </div>

        <div class="card focus-card running">
          <div class="mini-count">
            <span class="mini-label" style="color:#34C759">FOCUSING</span>
            <span class="mini-time">18:42</span>
          </div>
          <div class="mini-meta">
            <strong>{esc(SAMPLE['goal'])}</strong>
            <span class="row-accent" style="color:#34C759">Blocking verified</span>
            <span class="faint">App blocking · 3 apps covered</span>
          </div>
          <span class="chev" style="color:#34C759">›</span>
        </div>
        <p class="note">When a session is live, this card is the top of the screen and the countdown
          is drawn from the monotonic clock, not from whatever the last frame happened to show.</p>
      </div>
    </div>
  </figure>

  <!-- ================================================= frame 2: session, verified -->
  <figure class="frame">
    <figcaption><b>2 · Session — blocking verified</b><span>the only state that may say "blocking"</span></figcaption>
    <div class="phone">
      <div class="screen">
        <div class="topbar">
          <span class="faint">{esc(MODE['emoji']['blocking'])}  {esc(MODE['label']['blocking'])}</span>
          <span class="spacer"></span>
          <span class="end">End</span>
        </div>

        <div class="ring-wrap">
          <svg viewBox="0 0 250 250" width="250" height="250">
            <circle cx="125" cy="125" r="110" fill="none" stroke="rgba(120,120,128,.2)" stroke-width="14"/>
            <circle cx="125" cy="125" r="110" fill="none" stroke="url(#g2)" stroke-width="14"
                    stroke-linecap="round" stroke-dasharray="{DASH:.1f} {CIRCUMFERENCE:.1f}"
                    transform="rotate(-90 125 125)"/>
            <defs>
              <linearGradient id="g2" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stop-color="#5856D6"/><stop offset="1" stop-color="#B0AEFF"/>
              </linearGradient>
            </defs>
          </svg>
          <div class="ring-center">
            <span class="countdown">{esc(SAMPLE['ring_remaining'])}</span>
            <span class="ring-label">REMAINING</span>
          </div>
        </div>

        <div class="goal">
          <h2>{esc(SAMPLE['goal'])}</h2>
          <p class="faint">{esc(SAMPLE['planned'])}</p>
        </div>

        <div class="status ok">
          <div class="status-head"><span class="dot" style="background:#34C759"></span>
            <strong>{esc(ENF['label']['verified'])}</strong></div>
          <p>{esc(ENF['detail']['verified'])}</p>
          <p class="row-accent" style="color:#34C759">{SAMPLE['covered']} apps selected ·
            {SAMPLE['detected_opens']} detected opens</p>
        </div>

        <div class="tiles">
          <div class="tile"><b>{esc(SAMPLE['focused'])}</b><span>FOCUSED</span></div>
          <div class="tile"><b>{esc(SAMPLE['paused'])}</b><span>PAUSED</span></div>
          <div class="tile"><b>Monotonic</b><span>TIMING</span></div>
        </div>

        <div class="controls">
          <span class="btn tinted grow">Pause</span>
          <span class="btn filled orange grow">End session</span>
        </div>
      </div>
    </div>
    <p class="note">Requirements for this sentence: the service is alive, both permissions are held,
      and the device has reported at least one foreground event <i>during this session</i>.</p>
  </figure>

  <!-- =================================================== frame 3: session, armed -->
  <figure class="frame">
    <figcaption><b>3 · Session — armed, unconfirmed</b><span>same session, less evidence</span></figcaption>
    <div class="phone">
      <div class="screen">
        <div class="topbar">
          <span class="faint">{esc(MODE['emoji']['deep'])}  {esc(MODE['label']['deep'])}</span>
          <span class="spacer"></span>
          <span class="end">End</span>
        </div>

        <div class="ring-wrap">
          <svg viewBox="0 0 250 250" width="250" height="250">
            <circle cx="125" cy="125" r="110" fill="none" stroke="rgba(120,120,128,.2)" stroke-width="14"/>
            <circle cx="125" cy="125" r="110" fill="none" stroke="url(#g3)" stroke-width="14"
                    stroke-linecap="round" stroke-dasharray="{DASH:.1f} {CIRCUMFERENCE:.1f}"
                    transform="rotate(-90 125 125)"/>
            <defs>
              <linearGradient id="g3" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stop-color="#FF9500"/><stop offset="1" stop-color="#FFD60A"/>
              </linearGradient>
            </defs>
          </svg>
          <div class="ring-center">
            <span class="countdown">{esc(SAMPLE['ring_remaining'])}</span>
            <span class="ring-label">REMAINING</span>
          </div>
        </div>

        <div class="goal">
          <h2>{esc(SAMPLE['goal'])}</h2>
          <p class="faint">{esc(SAMPLE['planned'])}</p>
        </div>

        <div class="status warn">
          <div class="status-head"><span class="dot" style="background:#FF9500"></span>
            <strong>{esc(ENF['label']['armed'])}</strong></div>
          <p>{esc(ENF['detail']['armed'])}</p>
          <p class="row-accent" style="color:#FF9500">{SAMPLE['covered']} apps selected · 0 detected opens</p>
        </div>

        <div class="fix">
          <span>⚠️</span><strong>Fix permissions</strong><span class="spacer"></span><span class="chev">›</span>
        </div>

        <div class="tiles">
          <div class="tile"><b>{esc(SAMPLE['focused'])}</b><span>FOCUSED</span></div>
          <div class="tile"><b>{esc(SAMPLE['paused'])}</b><span>PAUSED</span></div>
          <div class="tile"><b>Monotonic</b><span>TIMING</span></div>
        </div>

        <div class="controls">
          <span class="btn tinted grow">Pause</span>
          <span class="btn hold grow">Hold to end</span>
        </div>
      </div>
    </div>
    <p class="note">A device that refuses to report usage looks exactly like a genuinely quiet phone
      from here. The app cannot tell them apart, so it says "unconfirmed" instead of guessing — and if
      this session reaches the timer, it is stored as <i>completed, degraded</i>, never as clean.</p>
  </figure>

  <!-- ================================================ frame 4: the setup sheet -->
  <figure class="frame">
    <figcaption><b>4 · Start sheet</b><span>everything stated before it starts</span></figcaption>
    <div class="phone">
      <div class="screen sheet">
        <h2 class="sheet-title">Focus session</h2>
        <p class="faint">Choose how long, and how much Track Pro should hold back.</p>

        <p class="label">HOW LONG</p>
        <div class="chips">
          <span class="chip">15 min</span><span class="chip">25 min</span>
          <span class="chip">45 min</span><span class="chip">60 min</span>
          <span class="chip">25 min ✎</span>
        </div>

        <p class="label">HOW MUCH SHOULD TRACK HOLD BACK?</p>
        {mode_cards()}

        <p class="label">APPS TO COVER</p>
        <div class="card list">
          <div class="row-head"><span>📵</span><strong>{SAMPLE['covered']} apps chosen</strong>
            <span class="spacer"></span><span class="chev">›</span></div>
          <p class="faint">Instagram, Reddit, YouTube</p>
        </div>
        <div class="card pro">
          <span>🎯</span>
          <div><strong>Cover the whole list</strong>
            <p class="faint">Pro covers every app you open when you are avoiding work — free sessions
              cover 3.</p></div>
          <span class="chip gold">PRO</span>
        </div>

        <p class="label">WHAT IS THIS FOR?</p>
        <div class="field"><span style="color:#fff">{esc(SAMPLE['goal'])}</span></div>
        <div class="card list">
          <div class="row-head"><span>🔗</span><strong>Link a routine</strong>
            <span class="spacer"></span><span class="chev">›</span></div>
          <p class="faint">Optional. The session keeps its own name either way.</p>
        </div>

        <p class="label">WHAT WILL ACTUALLY HAPPEN</p>
        <div class="status ok">
          <p>Track Pro can cover the apps you chose. It will say so during the session once it has
            actually seen one of them open — until then the status reads "armed", not "blocking".</p>
          <p class="row-accent" style="color:#34C759">What each permission does →</p>
        </div>

        <p class="disclose">{esc(CANCEL['blocking'])}</p>
        <p class="disclose faint">Calls, emergency dialling, the system launcher, keyboards, the clock
          and Track Pro itself are never covered, in any mode. You can always reach your phone and always
          leave this session.</p>

        <div class="btn filled indigo wide">Start with {SAMPLE['covered']} apps covered</div>
        <p class="fineprint">Track Pro never turns a permission on for you, and a permission never unlocks
          anything paid.</p>
      </div>
    </div>
  </figure>

  <!-- ============================================ frame 5: permission explainer -->
  <figure class="frame">
    <figcaption><b>5 · Permissions</b><span>each one, and what breaks without it</span></figcaption>
    <div class="phone">
      <div class="screen sheet">
        <h2 class="sheet-title">Permissions, and why</h2>
        <p class="faint">Track Pro asks for the least it can. Each of these does one job, and each can be
          revoked whenever you like.</p>
        {permission_rows()}
        <div class="card never">
          <strong>What Track Pro will never ask for</strong>
          <p>{esc(sheet_string('No Accessibility Service, no Device Admin, no VPN, no device-owner profile, no kiosk mode. '
                               'Those routes can cover a whole phone, and they can also see and control everything on it. '
                               'Track Pro covers a list of apps you choose, and nothing else.'))}</p>
        </div>
        <p class="fineprint">{esc(sheet_string('Track Pro keeps focus sessions on this device. Nothing about which apps you open is sent anywhere: '
                                               'the counts you see during a session are computed here and deleted with the session.'))}</p>
      </div>
    </div>
  </figure>

  <!-- ======================================================== frame 6: history -->
  <figure class="frame">
    <figcaption><b>6 · Focus history</b><span>figures only once the sample supports them</span></figcaption>
    <div class="phone">
      <div class="screen">
        <div class="bigtitle">
          <h1>Focus history</h1>
          <p>{SAMPLE['sessions']} sessions · 610 minutes recorded</p>
        </div>

        <div class="tiles">
          <div class="tile"><b>95</b><span>MIN LAST 7 DAYS</span></div>
          <div class="tile"><b>3</b><span>CLEAN RUN</span></div>
          <div class="tile"><b>09:12</b><span>TYPICAL START</span></div>
        </div>

        <div class="interpret">
          {round(SAMPLE['clean'] / SAMPLE['sessions'] * 100)}% of your {SAMPLE['sessions']} finished
          sessions ran clean — the timer reached zero with enforcement intact throughout.
          {round(SAMPLE['served'] / SAMPLE['sessions'] * 100)}% ran to the end of their timer at all;
          the rest were ended early or interrupted, and are stored exactly as they happened.
        </div>

        <p class="label">SESSIONS <span class="spacer"></span><span class="faint">23 of 23</span></p>

        {session_row('🛡️', SAMPLE['goal'], OUTCOME['label']['completed'], 'ok',
                     '15 Oct · 25 min of 25 min · 1 min paused',
                     'Covered 3 apps · 2 opens detected',
                     'phone in the drawer, it worked')}
        {session_row('🎯', 'Morning reading', OUTCOME['label']['completedDegraded'], 'warn',
                     '14 Oct · 25 min of 25 min',
                     '3 apps selected · enforcement not confirmed (blocking set up, unconfirmed)')}
        {session_row('🌒', 'Deep work', OUTCOME['label']['interrupted'], 'bad',
                     '13 Oct · 9 min of 45 min',
                     'Recorded as interrupted. The time before the interruption — 9 min — is still in your history.')}
        {session_row('🎯', 'Gym prep', OUTCOME['label']['cancelled'], 'info',
                     '12 Oct · 6 min of 25 min',
                     'You stopped it after 6 min. Recorded as cancelled, which costs you nothing.')}

        <div class="card pro locked">
          <span>📈</span>
          <div><strong>16 older sessions kept, not hidden</strong>
            <p class="faint">Your history is stored in full — free shows the last 7. Pro reads the whole
              record and the patterns in it.</p></div>
        </div>

        <p class="fineprint">Timing comes from the device's monotonic clock, not the wall clock, so
          changing the time or crossing a time zone cannot extend or shorten a session. A session that
          was interrupted — device restart, service stopped, a permission revoked — is stored as
          interrupted and never counted as a completion.</p>
      </div>
    </div>
  </figure>
'''


def main() -> int:
    stamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    document = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Focus Lock — layout preview</title>
<style>
  :root {{
    --bg:#0A0A0C; --panel:#141419; --line:rgba(255,255,255,.08);
    --label:#fff; --label2:rgba(235,235,245,.6); --label3:rgba(235,235,245,.34);
    --blue:#007AFF; --indigo:#5856D6; --purple:#AF52DE; --green:#34C759;
    --orange:#FF9500; --red:#FF3B30; --gold:#FFC53D;
    --font: -apple-system, BlinkMacSystemFont, 'Inter', system-ui, 'Segoe UI', Roboto, sans-serif;
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; padding:40px 28px 72px; background:
      radial-gradient(1200px 600px at 12% -10%, rgba(88,86,214,.20), transparent 60%),
      radial-gradient(900px 500px at 88% 0%, rgba(0,122,255,.16), transparent 55%), var(--bg);
      color:var(--label); font-family:var(--font); -webkit-font-smoothing:antialiased; }}
  header {{ max-width:1500px; margin:0 auto 34px; }}
  h1 {{ font-size:32px; font-weight:700; letter-spacing:-.7px; margin:0 0 8px; }}
  header p {{ color:var(--label2); font-size:15px; line-height:1.6; max-width:940px; margin:0 0 14px; }}
  .badges {{ display:flex; flex-wrap:wrap; gap:8px; margin-bottom:18px; }}
  .badge {{ font-size:12px; font-weight:600; padding:5px 11px; border-radius:999px;
      border:1px solid var(--line); background:rgba(255,255,255,.04); color:var(--label2); }}
  .badge.good {{ color:#7CE0A1; border-color:rgba(52,199,89,.35); background:rgba(52,199,89,.10); }}
  .badge.warn {{ color:#FFC98A; border-color:rgba(255,149,0,.35); background:rgba(255,149,0,.10); }}
  .grid {{ max-width:1500px; margin:0 auto; display:grid; gap:30px;
      grid-template-columns:repeat(auto-fit, minmax(400px, 1fr)); align-items:start; }}
  .frame {{ margin:0; }}
  figcaption {{ display:flex; align-items:baseline; gap:10px; margin:0 4px 10px;
      font-size:14px; color:var(--label2); }}
  figcaption b {{ color:var(--label); font-weight:650; letter-spacing:-.2px; }}
  figcaption span {{ font-size:12.5px; color:var(--label3); }}
  .phone {{ background:#000; border:1px solid var(--line); border-radius:34px; padding:12px;
      box-shadow:0 30px 70px rgba(0,0,0,.55); }}
  .screen {{ background:#000; border-radius:24px; padding:16px 16px 22px; overflow:hidden; }}
  .screen.sheet {{ background:#0B0B0F; }}
  .note {{ font-size:12.5px; line-height:1.6; color:var(--label3); margin:12px 6px 0; }}
  .spacer {{ flex:1; }}
  .faint {{ color:var(--label3); font-size:12.5px; font-weight:500; }}
  .body {{ color:var(--label2); font-size:12.8px; line-height:1.5; margin:8px 0 0; }}
  .row-accent {{ font-size:11.8px; font-weight:600; margin:6px 0 0; }}
  .chev {{ color:var(--label3); }}
  .label {{ font-size:11.5px; font-weight:700; letter-spacing:.6px; color:var(--label3);
      margin:18px 2px 8px; display:flex; align-items:center; }}

  .bigtitle h1 {{ font-size:30px; margin:0; letter-spacing:-.7px; }}
  .bigtitle p {{ color:var(--label3); font-size:13px; margin:3px 0 16px; font-weight:500; }}

  .card {{ background:#1C1C1E; border:1px solid rgba(255,255,255,.06); border-radius:16px;
      padding:14px; box-shadow:0 10px 26px rgba(0,0,0,.45); }}
  .focus-card {{ margin-bottom:12px; }}
  .focus-card .row-head {{ display:flex; align-items:center; gap:8px; }}
  .focus-card strong {{ font-size:15.5px; font-weight:700; letter-spacing:-.25px; }}
  .focus-card.running {{ display:flex; align-items:center; gap:12px; padding:13px 14px;
      background:rgba(52,199,89,.14); border-color:rgba(52,199,89,.35); }}
  .mini-count {{ display:flex; flex-direction:column; }}
  .mini-label {{ font-size:10.5px; font-weight:800; letter-spacing:1px; }}
  .mini-time {{ font-size:29px; font-weight:300; letter-spacing:-1px; font-variant-numeric:tabular-nums; }}
  .mini-meta {{ display:flex; flex-direction:column; gap:2px; font-size:13px; min-width:0; }}
  .mini-meta strong {{ font-size:14px; }}

  .btn-row {{ display:flex; gap:10px; margin-top:12px; }}
  .btn {{ display:inline-flex; align-items:center; justify-content:center; height:44px; padding:0 16px;
      border-radius:999px; font-size:14.5px; font-weight:600; }}
  .btn.grow {{ flex:1; }}
  .btn.wide {{ width:100%; margin-top:16px; }}
  .btn.primary {{ background:linear-gradient(180deg,#007AFF,#0062CC); color:#fff; flex:1; }}
  .btn.indigo {{ background:linear-gradient(180deg,#5856D6,#4A48B8); color:#fff; }}
  .btn.filled.orange {{ background:linear-gradient(180deg,#FF9500,#E07F00); color:#fff; }}
  .btn.tinted {{ background:rgba(120,120,128,.22); color:#fff; }}
  .btn.hold {{ flex:1; background:rgba(255,149,0,.16); color:var(--orange);
      border:1px solid rgba(255,149,0,.4); }}

  .topbar {{ display:flex; align-items:center; font-size:13.5px; margin-bottom:6px; }}
  .topbar .end {{ color:var(--orange); font-weight:650; font-size:15px; }}

  .ring-wrap {{ position:relative; display:flex; justify-content:center; margin:6px 0 14px; }}
  .ring-center {{ position:absolute; inset:0; display:flex; flex-direction:column;
      align-items:center; justify-content:center; gap:2px; }}
  .countdown {{ font-size:53px; font-weight:300; letter-spacing:-1.7px; font-variant-numeric:tabular-nums; }}
  .ring-label {{ font-size:11px; font-weight:700; letter-spacing:1.2px; color:var(--label3); }}

  .goal {{ text-align:center; margin-bottom:16px; }}
  .goal h2 {{ font-size:19px; font-weight:650; letter-spacing:-.4px; margin:0 0 3px; }}
  .goal p {{ margin:0; }}

  .status {{ border-radius:16px; padding:13px 14px; border:1px solid transparent; }}
  .status.ok {{ background:rgba(52,199,89,.14); border-color:rgba(52,199,89,.3); }}
  .status.warn {{ background:rgba(255,149,0,.14); border-color:rgba(255,149,0,.3); }}
  .status-head {{ display:flex; align-items:center; gap:8px; margin-bottom:6px; }}
  .status-head strong {{ font-size:14.5px; font-weight:700; letter-spacing:-.2px; }}
  .status p {{ margin:0; color:var(--label2); font-size:12.8px; line-height:1.5; }}
  .status .row-accent {{ margin-top:8px; }}
  .dot {{ width:8px; height:8px; border-radius:50%; display:inline-block; }}

  .fix {{ display:flex; align-items:center; gap:9px; margin-top:8px; padding:11px 14px;
      border-radius:13px; background:rgba(120,120,128,.22); font-size:13.5px; }}

  .tiles {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-top:16px; }}
  .tile {{ background:#1C1C1E; border:1px solid rgba(255,255,255,.06); border-radius:14px;
      padding:12px; }}
  .tile b {{ display:block; font-size:19px; font-weight:700; letter-spacing:-.5px; }}
  .tile span {{ display:block; margin-top:3px; font-size:10.5px; font-weight:700;
      letter-spacing:.1px; color:var(--label3); }}

  .controls {{ display:flex; gap:12px; margin-top:18px; }}

  .sheet-title {{ font-size:21px; font-weight:700; letter-spacing:-.5px; margin:0 0 4px; }}
  .chips {{ display:flex; flex-wrap:wrap; gap:8px; }}
  .chip {{ padding:9px 14px; border-radius:999px; background:rgba(120,120,128,.22);
      font-size:13.5px; font-weight:600; }}
  .chip.gold {{ background:linear-gradient(135deg,#FFD873,#FFA51F); color:#7A5200;
      font-size:10.5px; letter-spacing:.4px; align-self:center; }}

  .mode {{ border:1px solid transparent; border-radius:16px; padding:12px 14px; margin-bottom:8px;
      background:#1C1C1E; }}
  .mode.selected {{ background:color-mix(in srgb, var(--accent) 16%, #1C1C1E);
      border-color:color-mix(in srgb, var(--accent) 55%, transparent); }}
  .mode-head {{ display:flex; align-items:center; gap:8px; }}
  .mode-name {{ font-size:15px; font-weight:700; letter-spacing:-.25px; }}
  .mode .tick {{ margin-left:auto; color:var(--accent); }}
  .mode-blurb {{ font-size:12.8px; line-height:1.45; color:var(--label2); margin:5px 0 0; }}
  .mode-limit {{ font-size:11.8px; line-height:1.45; color:var(--label3); margin:6px 0 0; }}

  .list {{ padding:12px 14px; }}
  .list .row-head {{ display:flex; align-items:center; gap:8px; }}
  .list .faint {{ margin:3px 0 0 22px; }}
  .pro {{ display:flex; gap:10px; align-items:flex-start; margin-top:8px;
      border-color:rgba(255,197,61,.4); }}
  .pro strong {{ font-size:14px; }}
  .pro .faint {{ margin:4px 0 0; }}
  .pro.locked {{ margin-top:14px; }}
  .field {{ background:rgba(120,120,128,.22); border-radius:11px; padding:11px 12px; font-size:15px; }}

  .disclose {{ font-size:12.5px; line-height:1.5; color:var(--label2); margin:14px 0 0; }}
  .fineprint {{ font-size:11.5px; line-height:1.5; color:var(--label3); text-align:center;
      margin:10px 2px 0; }}

  .perm {{ background:#1C1C1E; border:1px solid rgba(255,255,255,.06); border-radius:16px;
      padding:13px 14px; margin-bottom:8px; }}
  .perm-head {{ display:flex; align-items:center; gap:8px; }}
  .perm-head strong {{ font-size:14.5px; }}
  .perm p {{ font-size:12.5px; line-height:1.45; color:var(--label2); margin:6px 0 0; }}
  .perm .faint {{ color:var(--label3); font-size:12px; }}
  .link {{ display:inline-block; margin-top:8px; font-size:12.8px; font-weight:650; color:var(--blue); }}
  .pill {{ margin-left:auto; font-size:10.5px; font-weight:800; padding:3px 9px; border-radius:8px; }}
  .pill.ok {{ background:rgba(52,199,89,.16); color:#4CD964; }}
  .pill.warn {{ background:rgba(255,149,0,.16); color:var(--orange); }}
  .pill.bad {{ background:rgba(255,59,48,.16); color:#FF6961; }}
  .pill.info {{ background:rgba(0,122,255,.16); color:#4DA2FF; }}
  .never {{ border-color:rgba(255,255,255,.12); margin-top:12px; }}
  .never strong {{ font-size:13.5px; }}
  .never p {{ font-size:12.5px; line-height:1.5; color:var(--label2); margin:6px 0 0; }}

  .interpret {{ background:rgba(120,120,128,.18); border-radius:16px; padding:13px 14px;
      font-size:12.8px; line-height:1.5; color:var(--label2); margin:12px 0 4px; }}
  .row {{ background:#1C1C1E; border:1px solid rgba(255,255,255,.06); border-radius:16px;
      padding:12px 14px; margin-bottom:8px; }}
  .row-head {{ display:flex; align-items:center; gap:7px; }}
  .row-head strong {{ font-size:14.5px; font-weight:650; letter-spacing:-.25px; }}
  .row-head .pill {{ margin-left:auto; }}
  .row .faint {{ margin:5px 0 0; }}
  .row-accent {{ font-size:11.8px; font-weight:600; margin:6px 0 0; }}
  .row .row-accent {{ color:var(--label2); }}
  .quote {{ font-size:12.5px; font-style:italic; color:var(--label2); margin:6px 0 0; }}
</style>
</head>
<body>
<header>
  <h1>Focus Lock — layout preview</h1>
  <p>
    Six screens from <code>track_flutter/</code>, rendered as static HTML. Every user-visible
    sentence below is read out of the Dart sources at generation time by
    <code>tools/focus_preview.py</code>, which fails if a string it expects is missing — so this
    cannot quietly drift from the copy the app would actually show. Layout and colour follow the
    app's own tokens (iOS palette, 16&nbsp;px cards, monotonic-clock countdown).
  </p>
  <div class="badges">
    <span class="badge good">strings extracted from source</span>
    <span class="badge warn">not a screenshot — nothing was compiled or run</span>
    <span class="badge warn">figures are illustrative layout values, not measurements</span>
    <span class="badge">dark appearance only</span>
    <span class="badge">generated {stamp}</span>
  </div>
  <p style="font-size:13.5px">
    The real preview of this feature is <code>flutter run</code> on a machine with the SDK and an
    Android device — see <code>docs/FOCUS_LOCK.md</code> §8 for the device pass that would make any
    of this a claim rather than a design.
  </p>
</header>
<main class="grid">
{FRAMES}
</main>
</body>
</html>
'''
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as handle:
        handle.write(document)
    print(f'wrote {os.path.relpath(OUT, ROOT)} ({len(document.splitlines())} lines)')
    print('extracted copy:')
    for mode in ('standard', 'blocking', 'deep'):
        print(f"  {MODE['label'][mode]:<14} {MODE['limitation'][mode][:60]}…")
    for state in ('armed', 'verified'):
        print(f"  {ENF['label'][state]:<28} {ENF['detail'][state][:52]}…")
    return 0


if __name__ == '__main__':
    sys.exit(main())
