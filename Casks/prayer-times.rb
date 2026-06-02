# Homebrew Cask for Prayer Times (spec §7.8, §13).
#
# Place this in a tap repo (e.g. github.com/<you>/homebrew-tap as
# Casks/prayer-times.rb), then users install with:
#   brew install --cask <you>/tap/prayer-times
#
# The release workflow prints the version + sha256 to plug in here (or automate
# the bump with a PAT — see RELEASING.md). Sparkle and Homebrew coexist: both
# install the same notarized artifact.
cask "prayer-times" do
  version "0.2.1"
  sha256 "a23622f3f422ead2ac8b9009903c701e231798812f49193e2f4d3754a9d506c1"

  url "https://github.com/tareq1988/prayer-times-macos/releases/download/v#{version}/PrayerTimes-#{version}.zip"
  name "Prayer Times"
  desc "Menu bar app for Islamic prayer times"
  homepage "https://github.com/tareq1988/prayer-times-macos"

  # Sparkle handles in-app updates; let Homebrew defer to it.
  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Prayer Times.app"

  caveats <<~EOS
    This build is ad-hoc signed (not yet notarized), so macOS Gatekeeper blocks
    it on first launch. To open it, remove the quarantine attribute:

      xattr -dr com.apple.quarantine "/Applications/Prayer Times.app"

    Or: System Settings → Privacy & Security → "Open Anyway".
  EOS

  zap trash: [
    "~/Library/Preferences/co.tareq.prayertimes.plist",
    "~/Library/Caches/co.tareq.prayertimes",
  ]
end
