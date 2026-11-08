# FORK_CHANGES — every way Ben's iAPS differs from stock

**This file is the single source of truth** for customizations to `macconnellk/iAPS` and the pieces around it (middleware, scheduler, settings). It lives at the root of the fork's `main` branch; Tweaker keeps a mirror.

**Rule:** no change to the fork, the middleware or the scheduler ships without updating this file **in the same upload**. A change that isn't listed here doesn't exist as far as maintenance is concerned.

| | |
|---|---|
| Upstream | `Artificial-Pancreas/iAPS` `main` |
| Fork | `macconnellk/iAPS` `main` (last custom commit `3f0a2533`, Nov 7 2026) |
| Middleware repo | `macconnellk/middleware`, file `ClaudeMiddleware` (**v2.4**, Nov 8) |
| Divergence (Nov 7) | 7 custom files. **5 upstream commits not merged:** 8.3.92 version bump (`Config.xcconfig`), "Pre iOS 26 color update" (`ViewModifiers.swift`), and workflow changes. None touches a custom file |
| On Ben's phone | **TestFlight build 210** (installed Nov 7, 9:45 AM) |

## 1. Summary

### In the fork's code

| ID | Change | Files | In builds | Upstream merge risk |
|---|---|---|---|---|
| **F1** | COB monotonicity clamp (Spec D) | `FreeAPS/Sources/APS/OpenAPS/OpenAPS.swift` | ≤206 → 210 | Medium: hooks `determineBasal`; the block is self-contained at the end of the file |
| **F2** | Constant-rate minimum carb absorption ("carb floor") | `FreeAPS/Resources/javascript/prepare/profile.js` | ≤206 → 210 | Low: one block at the end of `generate()` |
| **F3** | Bolus calculator: falling-glucose trend guard, pacing fix, TG note marker | `FreeAPS/Sources/Modules/Bolus/BolusStateModel.swift`, `.../Bolus/View/AlternativeBolusCalcRootView.swift` | ≤206 → 210 | **High:** upstream edits these files often |
| **F4** | Remote-command poll bypasses the URL cache (Spec G) | `FreeAPS/Sources/Services/Network/NightscoutAPI.swift` | 208 → 210 | Low: one line |
| **F5** | Override presets uploaded to Nightscout (Spec H) | `FreeAPS/Sources/Services/Network/NightscoutManager.swift`, `FreeAPS/Sources/Models/NightscoutStatus.swift` | 210 | Medium: hooks `uploadProfileAndSettings` and `uploadStatus` |

### Outside the fork's code

| ID | Change | Lives in | Current |
|---|---|---|---|
| **M1** | Middleware: **sleep mode (changes dosing overnight)**, status line, autoISF settings token | **Canonical: `macconnellk/middleware` → `ClaudeMiddleware`.** Runs from the iAPS in-app editor (Settings → Middleware). Tweaker copy: `middleware/spec-e/middleware_v2.3.js` | **v2.4** (Nov 8) |
| **S1** | Preset Scheduler: Google Calendar "iAPS Presets" → Nightscout announcement → iAPS starts the preset | Google Apps Script. Source: Tweaker `preset-scheduler/` | **v1.4** (live Nov 6) |
| **P1** | Settings the custom code depends on | Ben's phone | See §4 |

**Retired:** iOS Shortcuts automations that started presets (turned off Nov 7; the calendar is now the only automatic trigger).

## 2. Fork code changes

### F1 — COB monotonicity clamp (Spec D)

- **Why:** oref's `meal.js` rebuilds COB from the whole carb history every loop. It credits past slots at the *current* ISF/CR. So at an ISF or CR schedule boundary, COB can jump **up** with no new carbs, and the phantom carbs drive extra SMBs.
  - Sep 22: COB 75 → 86 at the 20:00 ISF change (147 → 115), an 11 g phantom.
  - Sep 15: a CR boundary, 3.2 g.
- **What:**
  - In `determineBasal(currentTemp:clock:temporary:override:)`, the `meal(...)` result (`orefMeal`) passes through `COBMonotonicityClamp.apply(...)`.
  - New `enum COBMonotonicityClamp` sits at file scope between `// BEGIN COBMonotonicityClamp` and `// END COBMonotonicityClamp`. It contains `evaluate`, `apply`, `floorRate`, the carb/entry fingerprints and state load/save.
  - State is kept in `UserDefaults` key `COBMonotonicityClamp.state.v2`. The spec r1 used `.v1`; the Sep 28 rewrite moved it to v2.
- **Behaviour:**
  - Reported COB ≤ trusted COB − (floor g/hr × elapsed) + one 5-minute slot.
  - It is a `min()` only: it never raises COB and never slows a faster decay.
  - It resets on new carb fingerprints, a move in `lastCarbTime`, the first run, or a gap.
  - The floor is shared with F2 (`min5mCarbimpact` read as g/hr, bounded 5–40, default 20).
  - It writes `orefMealCOB`, `cobClampDecision` and `cobClampHeld` into the meal JSON. The middleware reports `COB held`.
- **Commits:** `4c80e8be` (Sep 26), `91f1ea89` (Sep 28 rewrite).
- **Spec and tests:** Tweaker `iaps-fork/cob-clamp/spec-d-cob-monotonicity-clamp.md`. Harness `COBClampHarness.swift` (78 assertions) and `run_cob_clamp_harness.sh`. Simulator report Sep 26.
- **Rollback:** restore upstream `OpenAPS.swift`. The state key is then ignored.

### F2 — Constant-rate minimum carb absorption

- **Why:** oref converts `min_5m_carbimpact` (mg/dL per 5 min) back to grams as `impact × CR / ISF`. So a fixed setting gives a minimum absorption rate that swings with the schedule: 5.5 g/hr at 09:00 versus 14.3 g/hr at 03:00 on this profile, a 2.6× spread with no physiological basis.
- **What:** a block at the end of `generate()` in `prepare/profile.js`.
  - It **reinterprets `min_5m_carbimpact` as grams per hour**, bounded 5–40 with a default of 20.
  - It derives the mg/dL value oref expects from the active ISF and CR on every loop (`makeProfiles()`).
- **Warning in the code:** the setting is now read in g/hr. Left at oref's default of 8, it means 8 g/hr.
- **Commits:** `28b86fbd`, `94005409` (Aug 4).
- **Rollback:** remove the block. **Then set `min_5m_carbimpact` back to an mg/dL value.**

### F3 — Bolus calculator changes

`BolusStateModel.swift` (about +200/−12) and `AlternativeBolusCalcRootView.swift` (about +58/−1). Commits run from 2025-05 to 2026-08-03; the main ones are `f3527c80`, `6d3d8853` and `d2cacc33` (trend guard, Aug 1–3).

1. **Falling-glucose trend guard** (`fallingGlucoseScale()`).
   - **Why:** at a large ISF the calculator's glucose and trend terms add almost nothing to a carb-driven dose. At ISF 210, a BG of 90 against target 115 is only about −0.12 U. A multiplier can make a difference.
   - **What:**
     - It multiplies the final paced, IOB-credited recommendation, before rounding and the max-bolus clamp.
     - The multiplier is a smoothstep from `target` (×1) down to `threshold − 20` (× floor), applied to `projectedBG = BG + weight × deltaBG`. `deltaBG` spans 10 minutes.
   - **Gates:**
     - BG ≤ `target + 25`.
     - The fall needed is ≥ 5 over 10 min at or below `target − 15`, and ≥ 15 above it.
   - **Settings (UserDefaults, device):**
     - `trendGuardEnabled` (default on; a missing key reads as on)
     - `trendGuardDeltaWeight` (default 1.5, clamped 0–4)
     - `trendGuardFloor` (default 0.75, clamped 0.5–1)
2. **Pacing fix.**
   - **Why:** scaling the whole expression by `overrideFactor` also scaled the IOB credit. Reopening the calculator during a meal then re-offered (1 − factor) × IOB as a new dose, every time.
   - **What:** pacing (`fraction` = `overrideFactor`, and the fatty-meal factor) applies to the **gross requirement only**. IOB is credited at full value. `wholeCalc` keeps its old meaning, for display only.
3. **TG note marker** (`annotateGuardReduction()`).
   - **What:** when the guard trims a dose, `[TG-<pct>]` is appended to the carb note. An asterisk is added if the delivered amount was then changed by hand.
   - **Why:** the note uploads to Nightscout as `foodType`, so the nightly review can tell a guard-reduced dose from a manual override. `createdAt` is preserved for Nightscout de-duplication.
4. **oref eventual-glucose path pinned off** (`eventualBG = false` in `subscribe()`).
   - **Why:** that path bypasses `prepareData()`, so opening Calculations crashes on `data[1]`.
5. **UI** (`AlternativeBolusCalcRootView.swift`): a whole-percent guard-reduction row outside the disclosure, guard settings inside it, and an "OFF" marker on the label when the guard is disabled.
6. **Not custom (checked against upstream, Nov 7):** the bolus-sheet lifecycle code (`viewActive()` / `notActive()`, the suggestion-observer unregister, the auto-close) is identical in upstream `main`. It came in with an upstream merge.

**Rollback:** restore both files from upstream. The trend guard and pacing fix are lost, and the UserDefaults keys are ignored.

### F4 — Remote-command poll bypasses the URL cache (Spec G)

- **Why:**
  - After one enacted remote command, iAPS polls a byte-identical URL every 4 minutes.
  - iOS answered those polls from its URL cache (Nightscout sends `Last-Modified` and no `Cache-Control`).
  - So a later command could expire unseen. The Preset Scheduler (S1) depends on this fix.
- **What:** in `fetchAnnouncement(sinceDate:)`, set `request.cachePolicy = .reloadIgnoringLocalCacheData`. That is one statement plus one comment line.
- **Commit:** `c5b8fe61` (Nov 6). Build **208**.
- **Spec and tests:** Tweaker `iaps-fork/remote-cache/` (spec, harness H1–H7, mock Nightscout, device tests D1–D7). Report `test_report_2026-11-06.md`.
- **Known iAPS behaviour (not changed):** commands created within 10 minutes after an enacted one are never fetched (`syncDate` is the last enacted time + 10 min).

### F5 — Override presets uploaded to Nightscout (Spec H)

- **Why:** Nightscout held no preset settings. The nightly review needs exact names, stored durations, successors and end toggles without anyone keeping a list by hand.
- **What:**
  - `NightscoutProfileStore` gains `iapsOverridePresets` (schema 1). That is +1 line in `NightscoutStatus.swift`.
  - In `NightscoutManager.swift`:
    - `currentOverridePresetCatalog()`, built inside `viewContext.performAndWait`
    - `canonicalPresets()`: sorted keys, dates as the epoch, total order by id, name and bytes
    - `uploadOverridePresetsIfChanged()`, called at the end of `uploadStatus()` on `processQueue`
    - a private `uploadProfileAndSettings(_:nightscoutOnly:)`
    - the `presetUploadInFlight` flag, and the state file `upload/uploaded-ns-override-presets.json`
- **Behaviour:** every loop, a new Nightscout profile document is uploaded only if a preset changed. Successors are resolved from id to name.
- **Commits:** `1c877a94`, `3f0a2533` (Nov 7). Build **210**.
- **Spec and tests:**
  - Tweaker `Specs/iaps-and-scheduler-specs/spec_h_override_preset_catalog_upload.md` and rulings `Specs/rulings/pm_ruling_spec_h_*.md`.
  - Harness H1–H10 plus a ConcurrencyDebug control (`iaps-fork/preset-catalog/harness/`).
  - Device check Nov 7: 24 presets uploaded, Nightscout Pro keeps the field, no repeat uploads.
- **Read by:** tool v4.2.5 `presetCatalog`.

## 3. Outside the fork

### M1 — Middleware (v2.3)

- **Runs:** inside iAPS every loop (`middleware(iob, currenttemp, glucose, profile, autosens, meal, reservoir, clock)`), from the in-app editor.
- **Canonical source:** `macconnellk/middleware`, file `ClaudeMiddleware` (v2.3 header). Paste that file into the editor to deploy. **Update the repo first, then the phone.**
- **Sleep mode as it ran in v2.3 (until Nov 8),** from 21:00 to 03:00, when BG ≤ 140:
  - SMB and UAM are turned off, and the target is raised by 10. With an override target active and no temp target, the raise stacks on the override target.
  - **Hypo mode:** if IOB ≤ 0.1 U as well, the target goes up 40 more (+50 in total), and basal is scaled by a factor depending on BG and IOB:

    | Condition | Basal factor |
    |---|---|
    | BG > 140 (recovery) | × 0.95 |
    | IOB ≤ −0.2 | × 0.6 |
    | IOB ≤ −0.1 | × 0.75 |
    | IOB ≤ −0.05 | × 0.85 |
    | otherwise | × 0.9 |

  - ISF and CR are divided by 0.95. That raises both numbers, which means **less** insulin. The code comment says "Stronger"; the behaviour is protective and the comment is wrong.
- **Reporting only:** the carb floor back-computed in g/hr, and `COB held a→b` when F1 binds.
- **History:**
  - **v2.0** (Sep 29, Spec E): override handling handed back to native iAPS. Sleep mode still raises the target overnight.
  - **v2.1** (Sep 30): the status line reports the override-scaled ISF, CR and max IOB.
  - **v2.2** (Sep 30): adds `Target was/now` and the `MW v2.2 values pre-AutoISF` tag.
  - **v2.3** (Oct 14, Spec F): appends the `AISF[…]` autoISF settings token; `ovr=1` when a preset carries its own autoISF settings.
  - **v2.4** (Nov 8, spec `middleware/spec-e/spec-mw24-sleep-mode.md` r4): sleep mode realigned to its intent.
    - **Why:** v2.3's hypo mode ran in 55–76 % of 00:00–02:00 loops (target 165, basal × 0.6), and it released in one loop. The suspected cause of the 01:00–03:00 rebounds.
    - **What:**
      - hypo mode needs IOB ≤ 0, a fall of ≥ 8 per 15 min within the last 20 min, and BG ≤ 120
      - severity grades continuously on a 30-min projection
      - the base raise tapers from 110 to 140
      - SMBs are off only at IOB ≤ 0
      - ISF/CR softening is dropped
      - a 03:00–03:30 ramp
      - releases are capped at 20 per 5 min (stateless, reconstructed from the glucose history)
      - `SLEEP[...]` (settings) and `SLEEPSTATE[...]` (per loop, including `s` and `hold`) on the status line
    - **Tests:** harness 79/0 + 28/0, mutants 3/3 (`RUN_v2.4.md`).
    - **Rollback:** paste `middleware_v2.3.js` (md5 b82dfd5e).
    - **Watch:** two weeks against the Nov 7 baseline (hypo 55/76/47 % at 00/01/02 → ≤ 15 %; 02:00–04:00 peak median ≤ 150; hour 3 TIR ≥ 55 %), read through tool v4.2.6/v4.2.7.
- **Why it matters:** the tool reads the status line (override, ISF/CR, `Carb floor`, `COB held`, `AISF`) from the devicestatus `reason`.
- **Specs:** Tweaker `middleware/spec-e/` (Spec E, E.1, F, harnesses).
- **Rollback:** paste the previous version's file into the editor.

### S1 — Preset Scheduler (v1.4)

- **Flow:** Google Calendar "iAPS Presets" → Apps Script, every 5 min → Nightscout `override:<name>` announcement → iAPS starts the preset (needs F4).
- **Statuses:** VERIFIED, UNVERIFIED, SKIPPED_ACTIVE, SKIPPED_PENDING, REJECTED_TITLE, MISSED, NOOP_CANCEL.
- **Alerts:** silent from 10 PM to 7 AM.
- **Source and setup:** Tweaker `preset-scheduler/` (`SETUP.md`, the spec in `Specs/iaps-and-scheduler-specs/`). Production cutover Nov 6: NOOP posted 5:12 PM, started 5:20 PM, VERIFIED.

## 4. Settings the custom code depends on (P1)

| Setting | Read by | Meaning on this fork | Value on Ben's phone |
|---|---|---|---|
| `min_5m_carbimpact` (Preferences) | F2, F1 | **Grams per hour**, not mg/dL per 5 min | **24 g/hr** |
| `trendGuardEnabled` / `DeltaWeight` / `Floor` | F3 | Guard on / projection weight / minimum multiplier | on / 1.5 / 0.75 (confirm on device) |
| `overrideFactor` | F3 | Upfront fraction of the gross meal requirement; SMBs deliver the rest | 0.7 |
| Remote control | F4, S1 | Must be on for scheduler commands | on |
| `allowOneMinuteGlucose` | M1 (v2.4 fall memory, Δ15) | Off means glucose readings at least 4.5 min apart | off (5-minute readings) |
| Sleep-mode settings (v2.4) | M1 | `SLEEP[v1 win=2100-0330 base=140 raise=10 taper=30 smbiob=0.00 hiob=0.00 hd15=-8 mem=20 hbg=120 low=70 proj=2 hraise=40 bmin=0.60 soft=0 ramp=30 step=20]`; `step` must stay ≥ 17 | in `ClaudeMiddleware` CONFIG, printed on every status line |
| Override presets | F5, S1, review | Names must be exact; no `:`, `&`, `<` or `>` | 24 presets (Nov 7), uploaded by F5 |

## 5. Upstream merge checklist

Before merging upstream into the fork:
1. **Read this file.**
2. For each custom file, check whether upstream changed it: `compare/main...macconnellk:iAPS:main`.
3. **Re-apply each change by its markers and function names,** not by line numbers:
   - F1: the `BEGIN`/`END COBMonotonicityClamp` block and the `orefMeal` hook
   - F2: the "Constant-rate minimum carb absorption" block
   - F3: `fallingGlucoseScale`, the gross/net pacing block and `annotateGuardReduction`
   - F4: the `cachePolicy` line
   - F5: the catalog types and the two hooks
4. **Re-run the harnesses:** F1 (`run_cob_clamp_harness.sh`), F4 (`run_announcement_cache_harness.sh`), F5 (`run_spec_h_harness.sh`).
5. Bump the build, then put it on the test phone before Ben's.
6. **Update §1 and §6 of this file in the same upload.**

## 6. Build ledger

| TestFlight build | Date | Upstream base | Custom changes included |
|---|---|---|---|
| 206 | Sep 28 2026 | 8.3.6 | F1 (revision not recorded), F2, F3 |
| 208 | Nov 6 2026 | 8.3.9 | F1, F2, F3 (identical lines to 206), **+F4** |
| 210 | Nov 7 2026 | 8.3.9 | F1–F4, **+F5** |

**F1 as carried in 208 and 210 is the Sep 28 rewrite (`state.v2`). That is the intended version.**

## 7. Open items

- **Upstream lag:** 5 commits (8.3.92). Merge at the next build. Low risk, since no custom file is touched.
- **Marker comments:** whether to add a one-line `// FORK: <ID>` marker to each custom block the next time each file is touched (owner decision pending).
- **M1:** confirm that Tweaker's `middleware_v2.3.js` is byte-identical to the repo's `ClaudeMiddleware`. The headers match.
