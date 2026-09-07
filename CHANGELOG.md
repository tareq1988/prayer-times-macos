# Changelog

All notable changes to Prayer Times are documented here. This project adheres to
[Semantic Versioning](https://semver.org) and the
[Keep a Changelog](https://keepachangelog.com) format.

## [Unreleased]

### Added
- **"Time running out" reminder.** A second kind of reminder that fires a chosen number of minutes before a prayer's *last recommended* time rather than its astronomical end: Fajr 10 minutes before sunrise, Dhuhr until Asr, Asr 20 minutes before sunset (the makruh stretch), Maghrib until Isha, Isha until Islamic midnight (or Fajr). Lead time and per-prayer switches live in Notifications; the Asr margin and the Isha rule in Calculation → Prayer windows. The menu bar's "time left" mode now counts down to the same cut-off.
- **Automatic location keeps itself current.** In Automatic mode the location is re-detected every 30 minutes and right after the Mac wakes from sleep, so the times follow you when you travel with the app left running. The dropdown panel shows how old the fix is and when the next check is due (click that line to recheck now), and Settings → Location & time shows the place, coordinates and elevation on one line (opens in Google Maps) with when it was updated, the next check, and a Recheck now button. The panel's coordinates line opens the spot in Google Maps too. The last fix is remembered across relaunches, so the app starts from where it last was instead of from nothing, and a rebuilt app whose location permission macOS reset asks again instead of silently doing nothing.

### Fixed
- **Notification changes apply immediately.** Changing a reminder lead, a sound, or a per-prayer switch re-arms the schedule at once, instead of at the next day rollover or relaunch.

## [0.6.1] - 2026-08-30

### Fixed
- **Focus Mode's emergency exit is more reliable.** ⌘Esc is now handled at the overlay window as well as by the key monitor, and the overlay shows a localized **Dismiss** button whenever the emergency exit is enabled — so there is always a visible way out of the screen cover, not only a shortcut you have to remember.
- **The emergency exit no longer hinges on a single keycode.** Escape is matched by character as well as by keycode, so a remapped key or a non-US layout that delivers Escape on a different keycode still releases the block. ⌘` (grave — the key directly below Escape) is accepted as well: it is what a Command-held reach for Escape lands on when the hand shifts down a row, and what "Grave Escape" keyboards deliberately emit for Escape while Command is held.

## [0.6.0] - 2026-06-09

### Added
- **First-launch setup wizard.** A guided, designed walkthrough on first open — location, calculation method and madhab, notifications and permission, menu-bar display, and Focus Mode — so everything is configured in one pass. Re-run it anytime from Settings → General → "Run setup again".
- **Manual (fixed) time source.** For places where the mosque announces set jamaat times (e.g. Bangladesh), enter the five obligatory times yourself and have the Adhan reminder fire a chosen number of minutes before each. Switch it on in Calculation → Time source.
- **Focus Mode "Trigger on" and an Opaque blur level.** Choose whether the screen cover engages for the obligatory prayers, all prayer times, or Fajr & Isha only — and an Opaque intensity for a near-solid cover.
- **"Show Hijri date" toggle** for the dropdown panel.

### Changed
- **Redesigned Settings.** All five tabs were rebuilt in the modern macOS System Settings style. The Notifications tab is reorganized into shared defaults plus a compact per-prayer matrix (Notify · Adhan · Remind) with an inline override drawer, so per-prayer settings inherit the defaults instead of repeating every field.

### Fixed
- **The prayer sound now plays reliably at prayer time.** The chosen sound (e.g. Takbir) is played by the app itself at the prayer instant rather than riding on the macOS notification, whose custom sounds often failed to play — so what you hear on time matches the preview.
- **Focus Mode could miss a prayer when the app was idle.** The app is now kept out of App Nap, so its clock stays accurate and Focus Mode (and in-process Adhan) fire on time.

## [0.5.1] - 2026-06-08

### Fixed
- **Bengali menu bar countdown was ambiguous.** "Next prayer in X" and the new "time left in the current prayer" countdown both rendered with the same Bengali word (বাকি), so the two modes were indistinguishable. The upcoming countdown now reads with পর ("in"), distinct from বাকি ("left") for the current prayer.

## [0.5.0] - 2026-06-08

### Added
- **Today's Hijri (Islamic) date in the panel.** Shown beneath the Gregorian date, using the calculated Umm al-Qura calendar. Because the Islamic date can differ by country — Saudi Arabia and Bangladesh often observe Eid on different days — a **−2…+2 day adjustment** (Location & Time settings) lets you align it to your country's local moon-sighting. Localized month names and era in Arabic, Bengali, and Turkish.
- **"Time left in the current prayer" menu bar countdown.** A new option lets the menu bar count down to the *end* of the current prayer's window (e.g. "Asr 40m left") instead of the time until the next prayer — so you can see at a glance how long you still have to pray. Switch between the two in General settings.
- **Optional Ishraq time in the panel.** Enable "Show Ishraq time" to display when the voluntary Ishraq/Duha prayer becomes valid, listed right after Sunrise.

## [0.4.0] - 2026-06-06

### Added
- **JAKIM (Malaysia) calculation method.** Calibrated against JAKIM's official e-Solat tables so prayer times match what Malaysian users see in the official service — not the generic "Fajr 20°/Isha 18°" preset other apps mislabel as JAKIM, which runs Fajr about 11 minutes early. Auto-detect now selects JAKIM in Malaysia.
- **Kemenag (Indonesia) calculation method.** Calibrated against the official Kementerian Agama (Kemenag) tables, including the standard Indonesian *ihtiyati* safety minutes, so times match Kemenag's published schedule. Auto-detect now selects Kemenag in Indonesia.

### Fixed
- **Prayer times displayed up to a minute early.** Times were truncated to the minute instead of rounded, so a calculated 1:14:53 showed as "1:14" rather than "1:15". They are now rounded to the nearest minute — matching official prayer tables — across every calculation method, and the clock, notifications, and countdown all stay on the same minute.

## [0.3.1] - 2026-06-05

### Fixed
- **Missing Fajr and wrong Isha at high latitudes.** In northern locations (e.g. Kraków, Poland) the sun never reaches the required twilight depression angle in summer, so Fajr disappeared and Isha showed up near midnight. The app was discarding each calculation method's recommended high-latitude rule; it now honors it by default (e.g. Muslim World League's angle-based rule), so Fajr and Isha are computed sensibly and match the standard references.
- **New users got Istanbul prayer times.** A first-time install defaulted to a hardcoded manual Istanbul location, so someone opening the app in, say, Dhaka saw Istanbul times. First launch is now location-aware: it follows your system timezone immediately and asks to detect your location.
- **Switching from Automatic to Manual location lost your detected place.** Flipping to Manual snapped back to the old stored coordinates instead of keeping the location that was just detected. The detected coordinates now carry over.

### Changed
- **Menu bar now shows the icon, next prayer name, and countdown by default**, with the countdown written as "Asr in 4h 21m" / "in 21m" instead of the ambiguous "Asr 1:24". Fully localized (Arabic, Bengali, Turkish).
- **The menu bar mosque glyph is centered** and aligned with neighbouring menu bar icons.

## [0.3.0] - 2026-06-03

### Fixed
- **Wrong prayer times after auto-detecting location.** Detecting your location
  updated the coordinates but left the master timezone pointing elsewhere, so the
  times were computed for one place and shown on another's clock (e.g. Dhaka
  coordinates with an Istanbul timezone). Auto-detect now locks the timezone to
  the detected location, and the coordinates shown in Automatic mode are the ones
  actually in use.
- **Notifications not firing.** On a fresh install, notifications were scheduled
  before macOS granted permission and were never re-registered afterward. They are
  now rescheduled once permission resolves. Combined with the timezone fix above
  (which had pushed many alerts into the past), prayer notifications now fire at
  the correct local times.
- **"Detect my location" could hang** if tapped repeatedly or while a detection
  was already running; concurrent requests are now coalesced.
- **Adhan no longer replays on wake from sleep** for a prayer time that already
  passed while the Mac was asleep.
- **Settings are no longer reset on upgrade.** App settings now decode resiliently,
  so a future field addition can't wipe your configuration back to defaults.

### Added
- **In-app notification hint.** The Notifications settings tab now warns when macOS
  is blocking notifications, with a button to open System Settings — and prompts you
  to send a sample notification when permission hasn't been requested yet.
- **Timezone mismatch warning** in Location & Time when the timezone and detected
  location describe different places.
- All new strings are fully localized in Arabic, Bengali, and Turkish.

### Changed
- The Homebrew cask is now maintained solely in the
  [tap repo](https://github.com/tareq1988/homebrew-tap); the redundant in-repo copy
  was removed.

## [0.2.1] - 2026-06-02
- Fixed a launch crash in ad-hoc builds caused by hardened-runtime library
  validation rejecting the Sparkle framework.

## [0.2.0] - 2026-06-02
- Green app branding and menu bar glyph, "send a sample notification" button, README.

## [0.1.0] - 2026-06-02
- First public release: menu bar prayer times, configurable notifications, Adhan
  playback, pluggable calculation methods, Sparkle auto-update, and Homebrew cask.
