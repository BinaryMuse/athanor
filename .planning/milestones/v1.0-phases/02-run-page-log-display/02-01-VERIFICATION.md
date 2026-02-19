---
phase: 02-run-page-log-display
verified: 2026-02-17T00:00:00Z
status: gaps_found
score: 2/5 must-haves verified
re_verification: false
gaps:
  - id: GAP-01
    truth: "User can scroll up through log history without being jumped back to bottom"
    issue: "Scrolling up does not disable auto-scroll checkbox — user intent not reflected in UI state"
    severity: high
  - id: GAP-02
    truth: "Auto-scroll follows new entries when user is at bottom"
    issue: "During rapid streaming, auto-scroll toggle is unresponsive — UI cannot keep up with message volume"
    severity: high
  - id: GAP-03
    truth: "Page remains responsive with 10,000+ log entries"
    issue: "PubSub message clogging — experiment finished in 4s but UI updated for minutes; needs batching"
    severity: critical
human_verification:
  - test: "Open a run page with active logging; scroll up in log panel while logs are streaming"
    expected: "New log entries do NOT jump the scroll position back to the bottom while reading history"
    why_human: "MutationObserver near-bottom detection requires live DOM and real scroll state to confirm"
  - test: "Toggle the auto-scroll checkbox from OFF to ON while new logs are arriving"
    expected: "View immediately jumps to the bottom and continues following new entries"
    why_human: "updated() hook behavior on attribute change requires live browser interaction to confirm"
  - test: "Let 10,000+ log entries accumulate (or simulate via batch inserts)"
    expected: "Page remains responsive — scrolling and interaction do not lag; DOM stays bounded at ~1000 nodes"
    why_human: "Browser performance under real load cannot be verified statically"
  - test: "Inspect rendered log rows for error and warn levels"
    expected: "error rows display red (text-error), warn rows display yellow/warning (text-warning); each row has a badge with correct color"
    why_human: "DaisyUI badge classes require a running browser to confirm color rendering"
---

# Phase 2: Run Page Log Display Verification Report

**Phase Goal:** Users can monitor high-volume experiment logs without browser performance degradation
**Verified:** 2026-02-16T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                          | Status     | Evidence                                                                                                   |
| --- | ------------------------------------------------------------------------------ | ---------- | ---------------------------------------------------------------------------------------------------------- |
| 1   | Log panel displays new entries as they arrive in real-time                     | VERIFIED   | PubSub subscription in mount/3; handle_info({:log_added, log}) does stream_insert with limit              |
| 2   | Page remains responsive with 10,000+ log entries (DOM capped at 1000 nodes)   | GAP        | DOM bounded correctly, but PubSub message volume causes UI lag — experiment ran 4s, UI updated for minutes |
| 3   | Auto-scroll follows new entries when user is at bottom                         | GAP        | Toggle unresponsive during rapid streaming — UI cannot keep up with message volume to process clicks       |
| 4   | User can scroll up through log history without being jumped back to bottom     | GAP        | isNearBottom() works, but scrolling up does not disable auto-scroll checkbox — user intent not captured    |
| 5   | Log levels (debug/info/warn/error) are visually distinct with semantic badges  | VERIFIED   | level_badge/1 maps all four levels to badge-error/badge-warning/badge-info/badge-ghost classes            |

**Score:** 2/5 truths verified

### Required Artifacts

| Artifact                                                                                     | Expected                                                 | Status   | Details                                                                                      |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex`                 | LogPanel Phoenix.Component for log rendering             | VERIFIED | 65 lines, non-stub; exports log_panel/1 with full HEEx template, level_badge, format_timestamp |
| `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex`                        | Bounded stream with limit on mount and insert            | VERIFIED | `@log_stream_limit 1_000` used in 3 stream calls (lines 29, 156, 169) and 2 DB queries (lines 18, 164) |
| `apps/athanor_web/assets/js/app.js`                                                         | AutoScroll hook with near-bottom detection               | VERIFIED | isNearBottom() defined at line 54 with 100px threshold; MutationObserver guards scroll at line 36 |

### Key Link Verification

| From                                           | To                                                     | Via                                                             | Status  | Details                                                                             |
| ---------------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------- | ------- | ----------------------------------------------------------------------------------- |
| `run_live/show.ex`                             | `components/log_panel.ex`                              | `alias ... LogPanel` + `LogPanel.log_panel` call                | WIRED   | Alias at line 6; function call at line 81 in render/1                              |
| `run_live/show.ex`                             | stream/4 and stream_insert/4                           | `limit: -@log_stream_limit` on all three call sites             | WIRED   | Lines 29, 156, 169 all include the limit; module attribute defined at line 8        |
| `assets/js/app.js`                             | DOM logs-container element                             | phx-hook="AutoScroll" with isNearBottom check before scrolling  | WIRED   | Hook registered in Hooks object; spread into liveSocket at line 67; logs-container has phx-hook="AutoScroll" (log_panel.ex line 32) and data-auto-scroll attribute (line 33) |

### Requirements Coverage

| Requirement | Status    | Blocking Issue |
| ----------- | --------- | -------------- |
| LOG-01 — Run page: virtualized log display for high-volume output | GAPS | PubSub message clogging causes UI lag; auto-scroll UX issues under load |

### Anti-Patterns Found

None detected. No TODO/FIXME/placeholder comments, no empty return values, no stub handlers in any of the three modified files.

### Human Verification Required

#### 1. Auto-scroll non-interruption under live logging

**Test:** Open a run page for an actively-producing experiment. Scroll upward in the log panel. Observe whether new log entries (visible as the list grows) snap the view back to the bottom.
**Expected:** The view stays at the user's current scroll position. New entries are added but do not move the scroll.
**Why human:** The `isNearBottom()` function computes `scrollHeight - scrollTop - clientHeight <= 100`. This requires a real rendered DOM with actual pixel dimensions; cannot be confirmed via static analysis.

#### 2. Auto-scroll re-enable jump

**Test:** With logs streaming and auto-scroll OFF (scroll position somewhere in the middle), click the auto-scroll toggle to turn it ON.
**Expected:** The view immediately jumps to the bottom and then continues following new entries.
**Why human:** The `updated()` Phoenix LiveView hook fires when the server re-renders the `data-auto-scroll` attribute. Requires a live browser session to confirm the hook fires and the scroll jump occurs.

#### 3. Performance under high volume (10,000+ entries)

**Test:** Run an experiment that produces or simulate 10,000+ log entries (e.g., via `Experiments.create_log` in IEx). Monitor page responsiveness.
**Expected:** After the initial bounded load of 1000 entries, the page remains interactive. Scrolling is smooth. Each new entry triggers a stream_insert that evicts the oldest entry, keeping the DOM at 1000 nodes.
**Why human:** Browser rendering performance cannot be confirmed from file inspection. The stream limit logic is correctly implemented but the actual DOM behavior under load requires observation.

#### 4. Log level badge rendering

**Test:** View a run page with logs at all four levels (debug, info, warn, error).
**Expected:** Each level displays a visually distinct badge: error (red), warn (yellow/amber), info (blue), debug (neutral/ghost). Error rows have red text, warn rows have warning-colored text.
**Why human:** DaisyUI badge colors (`badge-error`, `badge-warning`, `badge-info`, `badge-ghost`) resolve to CSS custom properties from the active theme. Requires a browser to confirm actual color rendering.

### Gaps Summary

Human testing revealed 3 gaps that prevent phase goal achievement:

#### GAP-01: Auto-scroll checkbox doesn't reflect scroll position (High)
**Truth:** User can scroll up through log history without being jumped back to bottom
**Issue:** When user scrolls up, the `isNearBottom()` guard correctly prevents scroll-jump, but the auto-scroll checkbox remains checked. User intent (I scrolled away, stop following) is not reflected in UI state.
**Fix:** JS hook should push event to server when user scrolls away from bottom, disabling auto-scroll state.

#### GAP-02: Auto-scroll toggle unresponsive during rapid streaming (High)
**Truth:** Auto-scroll follows new entries when user is at bottom
**Issue:** During rapid log emission, clicking the auto-scroll checkbox often does nothing — the UI is too busy processing DOM updates to respond to user interaction.
**Fix:** Related to GAP-03; batching will reduce update frequency and restore UI responsiveness.

#### GAP-03: PubSub message clogging causes multi-minute UI lag (Critical)
**Truth:** Page remains responsive with 10,000+ log entries
**Issue:** Experiment completed in 4 seconds but UI continued updating for several minutes. Each log entry triggers a separate PubSub broadcast and LiveView update cycle. DOM is bounded correctly (1000 nodes) but message backlog causes severe lag.
**Fix:** Batch log broadcasts — accumulate logs in process state, flush at interval (e.g., 100ms) or count threshold. Single stream_insert per batch.

---

_Verified: 2026-02-16T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
