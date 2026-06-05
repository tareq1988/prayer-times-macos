<div align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Prayer Times icon">
  <h1>Prayer Times</h1>
  <p>A native, free macOS menu bar app for Islamic prayer times.</p>
  <br>
  <img src="docs/screenshot.png" width="620" alt="Prayer Times menu bar panel">
</div>

---

## Install

**Homebrew**
```sh
brew install --cask tareq1988/tap/prayer-times
```

**Direct download** — grab the latest `.zip` from
[Releases](https://github.com/tareq1988/prayer-times-macos/releases/latest).

> The current builds are ad-hoc signed (not yet notarized), so macOS Gatekeeper
> blocks them on first launch. To open: run
> `xattr -dr com.apple.quarantine "/Applications/Prayer Times.app"`, or go to
> **System Settings → Privacy & Security → Open Anyway**.

Requirements: **macOS 14 Sonoma or later** · Universal (Apple silicon + Intel).

## Features

- **Menu bar** next prayer + live countdown, with 7 label styles (icon / name / countdown / clock combinations) and a mosque glyph.
- **Glanceable panel** — today's six times with the next highlighted, iqamah times, date, and the active method/location. Adopts **Liquid Glass** on macOS 26 (Tahoe), with a material fallback on Sonoma/Sequoia.
- **8 calculation methods** — Diyanet (validated to ±1 minute against official tables), Muslim World League, ISNA, Umm al-Qura, Egyptian, Karachi, Moonsighting, and fully Manual — plus **Standard/Hanafi** Asr and **high-latitude** rules.
- **Notifications** per prayer: prayer-entry, early reminder (own lead time), and iqamah — each with its own sound. Plus a "send a sample" preview.
- **Full Adhan** playback (Makkah / Madinah) via in-process audio, with a Stop control (works around the 30-second notification-sound limit).
- **Location** — manual coordinates or one-shot CoreLocation auto-detect, with country → method mapping.
- **Localized** — English, العربية (RTL), Türkçe, বাংলা.
- **Launch at login** and **in-app auto-updates** (Sparkle), distributed via GitHub Releases + Homebrew.

## Architecture

```
PrayerKit/            Pure, UI-free Swift package (the calculation core + models)
  Calculation/        Engine, solar math, method adapters (no UI/IO, unit tested)
  Models/             Prayer, PrayerTimes, AppSettings, …
PrayerTimes/          The SwiftUI app (MenuBarExtra agent)
  App/ Settings/ Services/ Resources/
project.yml           XcodeGen project (the .xcodeproj is generated, git-ignored)
```

The calculation core is pure and fully unit-tested — including a hard gate that
reproduces official Diyanet monthly tables to ±1 minute. Everything Islam-specific
lives in **adapters** that produce parameters; the engine is a generic
astronomical calculator. See [`CLAUDE.md`](CLAUDE.md) for the full layout.

## Build & run

```sh
brew install xcodegen        # one-time
./scripts/run.sh             # build + install into /Applications + relaunch (ad-hoc signed)
cd PrayerKit && swift test   # run the calculation-core tests
```

`scripts/run.sh` regenerates the Xcode project when sources change. Or open the generated
`PrayerTimes.xcodeproj` in Xcode and hit Run.

## Releasing

```sh
# bump MARKETING_VERSION in project.yml, commit, then:
./scripts/release-local.sh 0.2.0
```
Builds a universal app, EdDSA-signs it for Sparkle, updates the appcast, publishes
the GitHub Release, and bumps the Homebrew cask. For notarized builds (no Gatekeeper
prompt), see [`RELEASING.md`](RELEASING.md).

## License

[MIT](LICENSE) © Tareq Hasan
