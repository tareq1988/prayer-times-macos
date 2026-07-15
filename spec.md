# Prayer Times — macOS Menu Bar App
### Technical Specification (v1.0)

> A native, free macOS menu bar application that displays Islamic prayer times,
> sends configurable notifications (including pre-prayer reminders and Adhan
> playback), supports multiple calculation methods via an adapter architecture,
> and self-updates through Sparkle / Homebrew. Distributed via GitHub.

---

## 1. Overview

The app lives permanently in the macOS menu bar as a lightweight agent
(no Dock icon). It shows the next prayer and a countdown in the menu bar,
expands to a panel listing the day's six times, and fires local notifications
at each prayer time — plus optional per-prayer "early" reminders with their own
lead time and sound. Calculation methods (Diyanet, MWL, ISNA, Umm al-Qura,
etc.) are pluggable, with an optional location-based auto-detect and a manual
override mode. The full Adhan can be played on prayer entry.

This document is the implementation contract. It assumes the calculation
engine and adapter design already agreed (see §6).

---

## 2. Goals & Non-Goals

### Goals
- Native macOS, SwiftUI-first, idiomatic and lightweight.
- Menu bar resident with a glanceable next-prayer countdown.
- Accurate prayer times for any location using a pluggable method system.
- Notifications at prayer time **and** configurable pre-prayer reminders.
- Per-prayer notification config: independent lead time and sound per prayer.
- Distinct sounds for "early reminder" vs "prayer entered" (Adhan).
- Settings for: calculation method, madhab (Asr), master timezone, location,
  high-latitude rule, and per-prayer notification preferences.
- Optional auto-detect of calculation method from location (off by default).
- Per-prayer **iqamah** offset (congregation time, N minutes after adhan).
- **Localization** (multiple languages, including RTL).
- Auto-update via Sparkle (in-app) and a Homebrew Cask (CLI users).
- Free, open distribution through GitHub Releases.

### Goals (nice-to-have)
- **Widget** (WidgetKit) showing the next prayer / today's times. Lower
  priority than the menu bar app itself; ship if time allows.
- User-imported custom Adhan files (bundled Adhans only).

### Non-Goals (v1)
- Qibla compass and Hijri date — explicitly out of scope.
- iCloud sync, iOS companion app.
- App Store distribution (direct/GitHub + Homebrew only).
- Multiple simultaneous locations / travel mode (future enhancement).

---

## 3. Technology Stack

| Concern | Choice | Rationale |
|---|---|---|
| Language | **Swift 6** (strict concurrency) | Native, modern, safe. |
| UI | **SwiftUI** + minimal AppKit bridging | `MenuBarExtra` is SwiftUI-native; AppKit only where SwiftUI gaps exist. |
| Menu bar | **`MenuBarExtra`** (`.window` style) | Available macOS 13+; `.window` style gives a rich custom panel. |
| Agent mode | `LSUIElement = true` | No Dock icon, no main window. |
| Notifications | **UserNotifications** (`UNUserNotificationCenter`) | Standard local-notification scheduling. |
| Audio (Adhan) | **AVFoundation** (`AVAudioPlayer`) | Bypasses the 30-second notification-sound limit (see §9). |
| Location | **CoreLocation** (one-shot `requestLocation`) | For auto-detect; never continuous tracking. |
| Reverse geocode | **CLGeocoder** | Map coordinates → country for method auto-detect. |
| Launch at login | **ServiceManagement** (`SMAppService.mainApp`) | Modern login-item API (macOS 13+). |
| Persistence | **UserDefaults** via `@AppStorage` + a `Codable` settings blob | Small config surface; no database needed. |
| Auto-update | **Sparkle 2.x** | De-facto standard for non-MAS macOS apps; EdDSA-signed appcast. |
| Package mgmt | **Swift Package Manager** | Sparkle and any deps via SPM. |
| CI / release | **GitHub Actions** | Build, sign, notarize, generate appcast, publish release. |
| Distribution | **GitHub Releases** + **Homebrew Cask** | Free, no developer-program hosting needed. |

### Calculation engine
Build a **custom Swift engine** (we already have the validated algorithm and
the adapter design). Do **not** take a hard dependency on a third-party prayer
library, because none model Diyanet's exact parameters (−1.9° horizon, +5 min
Dhuhr ihtiyat, +4 min Asr, shadow factor 1). The open-source
`batoulapps/Adhan-swift` may be used **only as a cross-check reference** during
testing, not as a runtime dependency.

---

## 4. System Requirements

- **Minimum deployment target:** macOS 14 Sonoma.
- **Supported:** macOS 14 Sonoma, 15 Sequoia, 26 Tahoe.
- **Liquid Glass:** Adopt the Tahoe Liquid Glass material where available
  (`macOS 26+`) and fall back gracefully to the standard material on
  Sonoma / Sequoia. See §10.
- **Architecture:** Universal binary (Apple silicon + Intel).
- **Signing:** Developer ID Application certificate + notarization (required
  for Gatekeeper on a directly-distributed app).

---

## 5. High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  App layer  (SwiftUI)                                          │
│  • MenuBarExtra (countdown + panel)                            │
│  • SettingsView (tabbed)                                       │
│  • AppDelegate / @main App                                     │
└───────────────┬───────────────────────────┬──────────────────┘
                │                           │
      ┌─────────▼─────────┐       ┌─────────▼──────────┐
      │  PrayerScheduler  │       │   SettingsStore    │
      │  (timers + day    │◄──────│  (@AppStorage +    │
      │   rollover)       │       │   Codable blob)    │
      └─────────┬─────────┘       └─────────┬──────────┘
                │                           │
   ┌────────────▼─────────────┐   ┌─────────▼──────────────┐
   │  NotificationService     │   │  CalculationCoordinator │
   │  • schedule prayer +     │   │  • picks adapter         │
   │    pre-prayer notifs     │   │  • resolves params       │
   │  • AudioService (Adhan)  │   │  • calls engine          │
   └──────────────────────────┘   └─────────┬──────────────┘
                                             │
                    ┌────────────────────────▼────────────────────────┐
                    │  Calculation core  (pure, testable, no UI)        │
                    │  Adapters → CalculationParameters → Engine        │
                    │  → SolarCalculator / HourAngle / HighLatitudeRule │
                    └───────────────────────────────────────────────────┘

   ┌──────────────────────┐   ┌──────────────────────┐
   │  LocationService     │   │  UpdateService        │
   │  (one-shot CL +      │   │  (Sparkle wrapper)    │
   │   reverse geocode)   │   │                       │
   └──────────────────────┘   └──────────────────────┘
```

Design rule: **the calculation core is pure** — no UI, no I/O, fully unit
testable. Everything Islam-specific (angles, shadow factors, offsets) lives in
adapters, never in the engine.

---

## 6. Calculation Engine (Adapter Pattern)

This is the architecture agreed earlier. Reproduced here as the build contract.

### 6.1 Adapter protocol
```swift
protocol CalculationMethodAdapter: Identifiable, Sendable {
    var id: String { get }            // stable key for persistence
    var displayName: String { get }   // shown in UI
    var summary: String { get }       // short description
    func resolve(for coordinates: Coordinates) -> CalculationParameters
}
```

### 6.2 Parameters (the contract)
```swift
struct CalculationParameters: Sendable, Equatable {
    var fajrAngle: Double                 // e.g. 18.0
    var ishaAngle: Double?                // nil if using fixed offset
    var ishaFixedMinutes: Int?            // e.g. Umm al-Qura = 90 (after Maghrib)
    var sunriseAngle: Double              // default -0.833; Diyanet -1.9
    var asrShadowFactor: Double           // 1.0 = Shafi/Maliki/Diyanet, 2.0 = Hanafi
    var dhuhrOffsetMinutes: Int           // Diyanet +5, others 0
    var asrOffsetMinutes: Int             // Diyanet +4, others 0
    var manualOffsets: [Prayer: Int]      // signed per-prayer fine tuning
    var highLatitudeRule: HighLatitudeRule
}

enum HighLatitudeRule: String, Codable, Sendable, CaseIterable {
    case none, middleOfNight, seventhOfNight, angleBased
}
```

### 6.3 Built-in adapters
- `DiyanetAdapter` — Fajr 18°, Isha 17°, sunrise −1.9°, shadow 1, Dhuhr +5, Asr +4.
- `MWLAdapter` — Fajr 18°, Isha 17°, shadow 1, angle-based high-lat.
- `ISNAAdapter` — Fajr 15°, Isha 15°, shadow 1.
- `UmmAlQuraAdapter` — Fajr 18.5°, Isha = Maghrib + 90 min (fixed), shadow 1.
- `EgyptianAdapter` — Fajr 19.5°, Isha 17.5°.
- `KarachiAdapter` — Fajr 18°, Isha 18° (University of Islamic Sciences).
- `MoonsightingCommitteeAdapter` — Fajr 18°, Isha 18°, seasonal twilight adj.
- `ManualAdapter` — every angle/shadow/offset user-supplied (also the debug tool).

### 6.4 Madhab as a composable modifier
Madhab is **not** a separate method. It is a wrapper that only changes the Asr
shadow factor, applied on top of any official method:
```swift
struct HanafiAsrModifier: CalculationMethodAdapter {
    let base: CalculationMethodAdapter
    var id: String { base.id + ".hanafi" }
    func resolve(for c: Coordinates) -> CalculationParameters {
        var p = base.resolve(for: c); p.asrShadowFactor = 2.0; return p
    }
}
```
In the UI: a primary "Calculation method" picker + a secondary "Asr (madhab)"
picker (Standard / Hanafi).

### 6.5 Engine signature
```swift
enum PrayerTimeEngine {
    static func calculate(
        date: DateComponents,
        coordinates: Coordinates,        // lat, lon, elevation
        params: CalculationParameters,
        timeZone: TimeZone
    ) -> PrayerTimes
}
```
Internals: `SolarCalculator` (declination, equation of time, transit),
`HourAngleCalc` (`angle(_:)`, `asr(_:)`, polar guards), `HighLatitudeRule`
post-processing, then per-prayer manual offsets. Output times are `Date`
values in the supplied `timeZone`.

### 6.6 Diyanet reference parameters (validated)
For QA, the Diyanet adapter must reproduce official tables to within ±1 minute.
Validated constants: Fajr −18.0°, Sunrise/Maghrib horizon −1.9°, Isha −17.0°,
Asr shadow factor 1.0, Dhuhr = transit + 5 min, Asr = computed + 4 min.

---

## 7. Feature Specifications

### 7.1 Menu bar presence
- `MenuBarExtra` with a compact label: next prayer name + countdown
  (e.g. `Asr 1:24`). User can choose label content in settings:
  - next prayer + countdown (default)
  - next prayer + clock time
  - icon only
- Clicking opens a `.window`-style panel:
  - Today's six times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha), the next one
    highlighted with a live countdown.
  - Today's Gregorian date.
  - Iqamah time shown next to each prayer when an iqamah offset is set.
  - Active method + location summary line.
  - Footer buttons: Settings…, Check for Updates…, Quit.
- Panel updates every second for the countdown; recomputes day's times on
  date rollover and on settings change.

### 7.2 Prayer calculation lifecycle
- On launch, on settings change, and at local midnight: compute today's (and
  tomorrow's, for the "next prayer after Isha" case) prayer times.
- `PrayerScheduler` holds the next event and (re)arms timers.
- Recompute when: method changes, madhab changes, location changes, timezone
  changes, system wake from sleep, or significant time change.

### 7.3 Notifications

#### Two notification types per prayer
1. **Pre-prayer reminder** ("early") — fires N minutes before; N is per-prayer.
2. **Prayer entered** — fires at the prayer time; can trigger Adhan playback.

#### Per-prayer configuration (independent for all six)
Each prayer has its own settings block:
```
Prayer: Dhuhr
  ├─ Prayer-time notification:   [on/off]
  │    └─ Sound:                 [None | Default | Adhan | Adhan (Makkah) | …]
  │    └─ Play full Adhan audio: [on/off]
  └─ Early reminder:             [on/off]
       └─ Lead time (minutes):   [ 20 ]      ← e.g. Dhuhr = 20, Maghrib = 10
       └─ Sound:                 [Soft chime | Default | …]
```
Requirement examples from product owner:
- Dhuhr: early reminder **20 min** before (time to bathe & prepare).
- Maghrib: early reminder **10 min** before.
- Early reminders use a **different (softer) sound** than the prayer-entry
  notification, which can use the **Adhan**.

#### Scheduling model
- Use `UNCalendarNotificationTrigger` (or `UNTimeIntervalNotificationTrigger`)
  for both the reminder and the prayer-entry notification.
- Reschedule the rolling window (today + tomorrow) whenever times recompute.
- Maintain stable notification identifiers per `(date, prayer, type)` so
  re-scheduling replaces rather than duplicates.
- Request `.alert`, `.sound`, `.badge` authorization on first run with a clear
  rationale; degrade gracefully if denied (panel still works, no notifications).

### 7.4 Per-prayer iqamah offset
- Iqamah is the congregation start, a configurable number of minutes **after**
  the prayer (adhan) time. Each of the five obligatory prayers (Fajr, Dhuhr,
  Asr, Maghrib, Isha — not Sunrise) has its own iqamah offset in minutes,
  default 0 (disabled).
- When an offset > 0 is set:
  - The panel shows the iqamah time beside that prayer (e.g. `Dhuhr 13:08 ·
    Iqamah 13:23`).
  - An optional **iqamah notification** can fire at the iqamah time, with its
    own on/off and sound (independent of the prayer-entry and early-reminder
    notifications).
- Iqamah is a pure display/notification concept layered on top of the computed
  prayer time — it does **not** touch the calculation engine or
  `CalculationParameters`.

### 7.5 Sounds & Adhan playback
- Bundle a small set of `.caf`/`.aiff` short sounds for notifications
  (chime, default, takbir snippet).
- Bundle one or more **full Adhan** audio files (Makkah, Madinah styles).
- **Critical constraint:** `UNNotificationSound` custom sounds are capped at
  ~30 seconds. A full Adhan exceeds this. Therefore:
  - The notification itself uses a **short** custom sound (e.g. opening takbir).
  - When "Play full Adhan audio" is enabled, the resident app **also** plays the
    full Adhan via `AVAudioPlayer` exactly at the prayer time (the app is always
    running as a menu bar agent, so an in-process timer fires reliably).
  - Provide a "Stop Adhan" control (panel button + notification action) and
    respect Focus / Do Not Disturb where the OS allows.
- See §9 for the audio-handling detail.

### 7.6 Settings screen
A standard SwiftUI `Settings` scene, tabbed:

**General**
- Launch at login (toggle → `SMAppService.mainApp`).
- Menu bar label style (countdown / clock / icon-only).
- Language override (Follow system | explicit), see §7.9.
- Check for updates automatically (toggle, wired to Sparkle).

**Location & Time**
- Location mode: **Automatic (CoreLocation)** | **Manual**.
  - Manual: search field (city) → geocode, or raw lat/lon/elevation entry.
- Master timezone: **Follow system** | **Pick explicitly** (the "master time").
- Show current resolved location + timezone read-only summary.

**Calculation**
- Calculation method picker (the built-in adapters).
- Asr / madhab picker (Standard | Hanafi).
- High-latitude rule picker.
- **Auto-detect method from location** (toggle, **OFF by default**) — when on,
  resolves country → method (see §7.7); user can still override.
- Manual method editor (revealed when "Manual" method chosen): fields for Fajr
  angle, Isha angle/fixed-minutes, Asr shadow factor, sunrise angle, and the
  five offsets.

**Notifications**
- Master notifications toggle.
- The per-prayer matrix from §7.3 (six rows, each with the two blocks).
- Per-prayer **iqamah offset** (minutes) + optional iqamah notification & sound.
- Sound pickers with a "play preview" button.
- "Stop Adhan" hotkey (optional).

### 7.7 Optional auto-detect of calculation method
- Off by default. When enabled:
  1. One-shot `requestLocation` → coordinates.
  2. `CLGeocoder` reverse-geocode → ISO country code.
  3. Look up a **country → method** mapping table; fall back to MWL if unknown.
  4. Surface the chosen method in the UI as "Auto: Diyanet (Türkiye)" so it's
     transparent, and let the user override (override disables auto until
     re-enabled).
- Suggested default mapping (extend as needed):
  | Country | Method |
  |---|---|
  | TR | Diyanet |
  | US, CA | ISNA |
  | SA | Umm al-Qura |
  | EG | Egyptian |
  | PK, IN, BD, AF | Karachi |
  | GB + N. Europe | MWL + high-lat angle-based |
  | (default) | MWL |

### 7.8 Auto-update
- **Sparkle 2.x** integrated for in-app updates:
  - EdDSA (ed25519) signing of releases.
  - `SUFeedURL` points to an **appcast.xml** hosted on GitHub
    (GitHub Pages or the `latest` release asset).
  - "Check for Updates…" menu item + automatic background checks (user toggle).
  - Deltas optional; full-zip updates are fine for v1.
- **Homebrew Cask** for terminal users:
  - Publish a cask in a tap repo (e.g. `wedevs/homebrew-tap` or a personal tap)
    pointing at the signed, notarized GitHub release asset, with the SHA256.
  - Cask and Sparkle coexist: Homebrew installs/updates the same notarized
    artifact; Sparkle handles in-app prompts for users who didn't use brew.
- **CI release flow (GitHub Actions):** build universal → sign (Developer ID)
  → notarize (notarytool) → staple → zip → compute EdDSA signature →
  update `appcast.xml` → create GitHub Release with the zip → (optionally) open
  a PR to bump the Homebrew cask version + SHA.

### 7.9 Localization
- All user-facing strings live in a **String Catalog** (`Localizable.xcstrings`);
  no hardcoded UI strings.
- Initial languages: **English, Arabic, Turkish, Bengali** (extendable).
- **RTL support** for Arabic — rely on SwiftUI's automatic layout mirroring;
  verify the menu bar panel, settings tabs, and notification text mirror
  correctly.
- Localize prayer names, settings labels, notification titles/bodies, and the
  method/madhab/high-latitude option names.
- Numbers, times, and dates formatted via `Date.FormatStyle` / locale-aware
  formatters (honoring the chosen language and the master timezone), so digits
  and AM/PM render per locale.
- Language follows the system by default, with an optional explicit override in
  General settings (§7.6).

### 7.10 Widget (nice-to-have)
- A **WidgetKit** extension surfacing prayer info on the desktop / Notification
  Center. Lower priority than the core app.
- Suggested families: `systemSmall` (next prayer + countdown) and
  `systemMedium` (all six times for today, next highlighted).
- Timeline driven by the same calculation core, with entries at each prayer
  boundary so the widget advances without the app running.
- Shares the calculation code and settings with the main app via a common
  framework/Swift package target and an **App Group** for settings access.
- Honors the active method, madhab, location, timezone, and language.

---

## 8. Core Data Models

```swift
enum Prayer: String, CaseIterable, Codable, Sendable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
}

struct Coordinates: Codable, Sendable, Equatable {
    var latitude: Double
    var longitude: Double
    var elevation: Double = 0
}

struct PrayerTimes: Sendable, Equatable {
    let date: Date                 // the calendar day (local)
    let times: [Prayer: Date]      // absolute Date per prayer
    func next(after now: Date) -> (prayer: Prayer, time: Date)?
}

struct PrayerNotificationConfig: Codable, Sendable {
    var prayerNotificationEnabled: Bool
    var prayerSound: NotificationSound
    var playFullAdhan: Bool
    var earlyReminderEnabled: Bool
    var earlyLeadMinutes: Int
    var earlySound: NotificationSound
    var iqamahOffsetMinutes: Int          // 0 = disabled (not used for Sunrise)
    var iqamahNotificationEnabled: Bool
    var iqamahSound: NotificationSound
}

enum NotificationSound: String, Codable, Sendable, CaseIterable {
    case none, systemDefault, softChime, takbir
    case adhanMakkah, adhanMadinah
    // .adhan* imply a short notification clip + AVAudioPlayer for the full file
}

struct AppSettings: Codable, Sendable {
    var methodID: String               // adapter id, or "manual"
    var manualParameters: CalculationParameters?
    var hanafiAsr: Bool
    var highLatitudeRule: HighLatitudeRule
    var locationMode: LocationMode     // .automatic / .manual
    var manualCoordinates: Coordinates?
    var timeZoneMode: TimeZoneMode     // .system / .explicit(identifier)
    var autoDetectMethod: Bool         // default false
    var menuBarStyle: MenuBarStyle
    var launchAtLogin: Bool
    var languageOverride: String?      // BCP-47 code, nil = follow system
    var notifications: [Prayer: PrayerNotificationConfig]
    var autoUpdateEnabled: Bool
}
```

---

## 9. Audio / Notification Sound Handling (detail)

The 30-second cap on `UNNotificationSound` is the key technical constraint.
Implement a two-path `AudioService`:

1. **Notification path** — every scheduled `UNMutableNotificationContent` uses a
   short bundled sound (≤30 s `.caf`). For "Adhan" selections this is the
   opening takbir clip so the alert still feels like an Adhan.
2. **In-process Adhan path** — `PrayerScheduler` keeps an in-app timer for the
   exact prayer instant. When it fires and `playFullAdhan` is on, `AudioService`
   plays the full file via `AVAudioPlayer`. Because the app is a resident menu
   bar agent it is reliably alive to do this. Provide stop control and avoid
   double audio (mute the notification's sound to `.none` when full Adhan is on,
   or keep only the short takbir — make this a tested, deliberate choice).

Edge cases to handle: system asleep at prayer time (notification still fires via
the OS; in-process Adhan may be missed — acceptable, document it), user logged
out, multiple rapid prayers (Maghrib→Isha), and DND/Focus.

---

## 10. Liquid Glass & Backward Compatibility

- Build against the latest SDK (Tahoe). On macOS 26+, adopt Liquid Glass for
  the menu bar panel and settings surfaces using the new material modifiers
  (e.g. `glassEffect` / `GlassEffectContainer`) gated behind
  `if #available(macOS 26, *)`.
- On macOS 14–15, fall back to the standard `.regularMaterial` /
  `.ultraThinMaterial` backgrounds so the UI remains correct and native.
- Centralize this in a small `GlassBackground` view modifier that branches on
  availability, so feature code stays clean:
  ```swift
  struct GlassBackground: ViewModifier {
      func body(content: Content) -> some View {
          if #available(macOS 26, *) {
              content.glassEffect()          // Liquid Glass on Tahoe
          } else {
              content.background(.regularMaterial)   // Sonoma/Sequoia
          }
      }
  }
  ```
- Do not hardcode Tahoe-only APIs anywhere outside availability checks.

---

## 11. Project Structure (suggested)

```
PrayerTimes/                          // workspace root
├── PrayerKit/                        // shared Swift package (app + widget use it)
│   └── Sources/PrayerKit/
│       ├── Calculation/              // PURE — unit tested, no UI/IO
│       │   ├── PrayerTimeEngine.swift
│       │   ├── SolarCalculator.swift
│       │   ├── HourAngleCalc.swift
│       │   ├── HighLatitudeRule.swift
│       │   ├── CalculationParameters.swift
│       │   ├── Coordinates.swift
│       │   └── Adapters/
│       │       ├── CalculationMethodAdapter.swift
│       │       ├── DiyanetAdapter.swift
│       │       ├── MWLAdapter.swift
│       │       ├── ISNAAdapter.swift
│       │       ├── UmmAlQuraAdapter.swift
│       │       ├── EgyptianAdapter.swift
│       │       ├── KarachiAdapter.swift
│       │       ├── MoonsightingCommitteeAdapter.swift
│       │       ├── ManualAdapter.swift
│       │       ├── HanafiAsrModifier.swift
│       │       └── MethodRegistry.swift   // id → adapter, country → method
│       └── Models/
│           ├── Prayer.swift
│           ├── PrayerTimes.swift
│           ├── AppSettings.swift
│           └── NotificationSound.swift
├── PrayerTimes/                      // main app target
│   ├── PrayerTimesApp.swift          // @main, MenuBarExtra, Settings scene
│   ├── App/
│   │   ├── AppDelegate.swift         // login item, lifecycle, Sparkle wiring
│   │   ├── MenuBarLabel.swift
│   │   └── MenuBarPanel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift        // tab container
│   │   ├── GeneralTab.swift
│   │   ├── LocationTimeTab.swift
│   │   ├── CalculationTab.swift
│   │   └── NotificationsTab.swift    // notifications + iqamah per prayer
│   ├── Services/
│   │   ├── PrayerScheduler.swift     // timers, day rollover, next event
│   │   ├── NotificationService.swift // UN scheduling (prayer/early/iqamah)
│   │   ├── AudioService.swift        // AVAudioPlayer + sound catalog
│   │   ├── LocationService.swift     // one-shot CL + reverse geocode
│   │   ├── SettingsStore.swift       // @AppStorage + Codable blob (App Group)
│   │   └── UpdateService.swift       // Sparkle wrapper
│   ├── Resources/
│   │   ├── Sounds/                   // short .caf clips
│   │   ├── Adhan/                    // full Adhan audio (bundled only)
│   │   ├── Localizable.xcstrings     // en, ar, tr, bn
│   │   └── Assets.xcassets
│   └── Supporting/
│       ├── Info.plist                // LSUIElement, usage strings, Sparkle keys
│       └── PrayerTimes.entitlements  // App Group; no sandbox
├── PrayerWidget/                     // WidgetKit extension (nice-to-have)
│   ├── PrayerWidget.swift            // small + medium families
│   ├── PrayerTimelineProvider.swift  // entries at prayer boundaries
│   └── Info.plist
└── Tests/
    ├── EngineTests.swift             // ±1 min vs Diyanet golden tables
    ├── AdapterTests.swift
    └── SchedulerTests.swift
```

The calculation core and models live in **PrayerKit**, a shared Swift package
consumed by both the app and the widget. Settings are shared through an
**App Group** so the widget reads the active method/location/language.

---

## 12. Permissions, Entitlements & Info.plist

- `LSUIElement` = `YES` (menu bar agent, no Dock).
- `NSLocationWhenInUseUsageDescription` — explain auto-detect use.
- UserNotifications authorization requested at runtime.
- **App Group** entitlement (`group.<bundle-id>`) shared between the app and the
  widget so both read the same settings and computed times.
- Hardened Runtime enabled (required for notarization).
- Sparkle keys in Info.plist: `SUFeedURL`, `SUPublicEDKey`,
  `SUEnableAutomaticChecks`.
- **App Sandbox: OFF.** The app is distributed via GitHub Releases and
  Homebrew (not the App Store), so sandboxing is not required. Security baseline
  is Developer ID signing + notarization (Gatekeeper approval + malware scan).
  Running unsandboxed avoids the known Sparkle-in-sandbox setup friction.
  Hardened Runtime stays **ON** (required for notarization).
- Entitlements: keep minimal — App Group plus Hardened Runtime, and any runtime
  exceptions notarization requires (typically none). No
  `com.apple.security.app-sandbox` entitlement.

---

## 13. Build, Signing, Distribution

1. Universal build (arm64 + x86_64), deployment target macOS 14, unsandboxed
   with Hardened Runtime enabled.
2. Sign with **Developer ID Application** certificate.
3. **Notarize** with `notarytool`, then **staple** the ticket.
4. Zip the `.app`, generate the **EdDSA signature** for Sparkle.
5. Update **`appcast.xml`** (version, URL, length, signature, min OS).
6. Publish a **GitHub Release** with the zip + appcast.
7. Update the **Homebrew Cask** (version + SHA256) in the tap repo.
8. Automate steps 1–7 in **GitHub Actions** triggered on a version tag.

License: choose an OSS license (MIT or GPL-3.0) since it's free and on GitHub.

---

## 14. Milestones (suggested phasing)

**M1 — Calculation core**
PrayerKit package: pure engine + adapters + unit tests passing ±1 min against
Diyanet golden tables for the three validated cities. No UI.

**M2 — Menu bar shell**
`MenuBarExtra` label + panel showing today's times and next-prayer countdown,
fed by the engine with a hardcoded location/method.

**M3 — Settings + persistence**
Full settings tabs, `SettingsStore` (App Group), method/madhab/high-lat
pickers, manual location & timezone, launch-at-login.

**M4 — Notifications + audio + iqamah**
`NotificationService` (prayer + per-prayer early reminders + per-prayer iqamah),
`AudioService` with short sounds and full-Adhan playback, sound previews,
Stop Adhan. Iqamah times shown in the panel.

**M5 — Location auto-detect**
CoreLocation one-shot + reverse geocode + country→method mapping, transparent
"Auto:" labeling, override behavior.

**M6 — Localization**
String Catalog with en/ar/tr/bn, RTL verification, locale-aware time/number
formatting, optional language override.

**M7 — Liquid Glass + polish**
Availability-gated glass material, Tahoe pass, Sonoma/Sequoia fallback QA.

**M8 — Auto-update + distribution**
Sparkle integration, appcast, GitHub Actions release pipeline, Homebrew cask,
notarization end-to-end.

**M9 — Widget (nice-to-have)**
WidgetKit extension (small + medium), timeline provider driven by PrayerKit,
App Group settings sharing. Ship if time allows.

---

## 15. Open Questions / Future Enhancements

- Multiple/saved locations and a travel mode.
- Per-prayer congregation/jamaah reminder distinct from iqamah display.
- Additional bundled Adhan voices.
- Additional languages beyond the initial four.
- Notification Center / Lock Screen complications beyond the desktop widget.

---

### Appendix A — Acceptance criteria for the engine
For the Diyanet adapter, the engine must reproduce the official Diyanet monthly
tables for Istanbul/Başakşehir, Ankara, and Istanbul/Arnavutköy to within
**±1 minute** for all six times across a full month. This is a hard test gate
for M1.
