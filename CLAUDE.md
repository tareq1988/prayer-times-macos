# CLAUDE.md

Guidance for working in this repository.

## What this is

**Prayer Times** — a native, free macOS menu bar app showing Islamic prayer
times with configurable notifications, Adhan playback, pluggable calculation
methods, localization, and Sparkle/Homebrew self-update. The full implementation
contract is `spec.md` (read it before non-trivial work). Distribution is GitHub
Releases + Homebrew Cask; **not** the App Store (so: unsandboxed, Developer ID +
notarization).

## Layout

```
spec.md                 # the implementation contract (source of truth)
project.yml             # XcodeGen project definition (app target)
PrayerTimes.xcodeproj   # GENERATED from project.yml — git-ignored, do not edit
PrayerKit/              # pure calculation core, a standalone SwiftPM package
  Sources/PrayerKit/Calculation/   # engine, solar math, adapters (no UI/IO)
  Sources/PrayerKit/Models/        # Prayer, PrayerTimes, AppSettings, …
  Tests/PrayerKitTests/            # 31 tests incl. the Diyanet ±1-min gate
PrayerTimes/            # the macOS app target (SwiftUI, MenuBarExtra)
  PrayerTimesApp.swift             # @main, MenuBarExtra + Settings scenes
  App/                             # PrayerClock, menu bar label/panel, helpers
  Supporting/Info.plist            # LSUIElement (menu bar agent)
  Resources/                       # Assets.xcassets
data/diyanet/           # official Diyanet CSV tables (source for the gate)
```

**Design rule (do not violate):** the calculation core in `PrayerKit` is pure —
no UI, no I/O, fully unit-testable. Everything Islam-specific (angles, shadow
factors, offsets) lives in **adapters** that produce `CalculationParameters`;
the engine is a generic astronomical calculator. Madhab is a *modifier*
(`HanafiAsrModifier`) over a method, not a separate method.

## Build, run, test

```bash
# Calculation core (fast, no Xcode project needed)
cd PrayerKit && swift test

# Regenerate the Xcode project after editing project.yml or adding files
xcodegen generate

# Build the app
xcodebuild -project PrayerTimes.xcodeproj -scheme PrayerTimes \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

The app is a menu bar agent (`LSUIElement`), so launching it shows an item in
the menu bar, not a window or Dock icon.

## Key facts (non-obvious; verified)

- **Engine accuracy is proven.** Astronomy is cross-checked against independent
  NOAA/timeanddate sun data; the Diyanet adapter reproduces the official June-2026
  tables (Ankara, Başakşehir, Arnavutköy) to ±1 minute for every row — the
  Appendix A hard gate (`DiyanetGoldenTableTests`).
- **Diyanet horizon is a flat −1.9°, with NO elevation term.** Adding a
  `0.0347·√elevation` dip correction over-lengthens the day at altitude and
  breaks the gate. Do not re-add it.
- District reference coordinates for the gate were calibrated to the tables
  (e.g. Başakşehir latitude 41.06). `DiyanetCalibration` is the dev-only
  re-tuning harness (skips when `data/` is absent).
- **JAKIM (Malaysia) is NOT the "Fajr 20°/Isha 18°" preset** that other apps
  label JAKIM — that runs Fajr ~11 min early against the official tables. JAKIM's
  e-Solat output (zone WLY01, Kuala Lumpur) behaves as Fajr **17.5°**, Isha 18°,
  plus *ihtiyati* safety minutes (Dhuhr +3, Asr +2, Maghrib +2, Isha +2). These
  reproduce e-Solat to ±1 min year-round (`JAKIMGoldenTableTests`). Do not
  "restore" 20°.
- **Kemenag (Indonesia)** uses Fajr **20°**, Isha **18°**, Shafiʿi Asr, plus
  *ihtiyati* minutes (Subuh +2, Dzuhur +3, Ashar +2, Maghrib +3, Isya +2 — the
  Dzuhur/Maghrib +3 absorbs Kemenag's round-up vs the engine's round-to-nearest).
  Calibrated against Kemenag's KOTA JAKARTA tables to ±1 min year-round
  (`KemenagGoldenTableTests`). Kemenag also defines Imsak = Subuh − 10, not shown.
- **The engine rounds each instant to the nearest minute** (not truncates).
  Published tables are minute-granular and round; truncating displayed every time
  up to ~1 min early (e.g. JAKIM Dhuhr 13:14:53 shown as 1:14 instead of 1:15).
  Rounding keeps the clock, the notification fire time, and the countdown on one
  minute boundary. Offsets are whole minutes, so spacing between times is
  preserved.
- `MoonsightingCommitteeAdapter` is an approximation — its seasonal twilight
  correction needs the date, which the location-only `resolve(for:)` contract
  can't pass. A known follow-up.

## Conventions

- **Swift 6, strict concurrency** everywhere (`SWIFT_STRICT_CONCURRENCY=complete`,
  language mode 6). UI/clock types are `@MainActor`.
- **Conventional Commits** for messages (`feat:`, `fix:`, `chore:`, `docs:`,
  `test:`, `refactor:`; scope optional, e.g. `feat(engine): …`). Reference the
  milestone in the body where relevant.
- Adding a source file to the app target? It's picked up by directory globbing —
  just run `xcodegen generate`. No manual `.pbxproj` edits.
- All user-facing strings will move to a String Catalog in M6; until then keep
  new strings centralized (e.g. `PrayerFormatting`) to ease that migration.

## Milestones (see spec §14)

M1 calculation core ✅ · M2 menu bar shell ✅ · M3 settings + persistence ✅ ·
M4 notifications + audio + iqamah ✅ · M5 location auto-detect ✅ ·
M6 localization ✅ (en/ar/bn/tr, 100%) · M7 Liquid Glass ✅ ·
M8 auto-update + distribution ✅ (Sparkle/appcast/cask; v0.2.1 shipped) ·
M9 widget (nice-to-have) — remaining. See the `prayer-times-status` memory for
the detailed per-milestone state.
