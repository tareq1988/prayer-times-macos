# Changelog

All notable changes to Prayer Times are documented here. This project adheres to
[Semantic Versioning](https://semver.org) and the
[Keep a Changelog](https://keepachangelog.com) format.

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
