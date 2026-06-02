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
  version "0.1.0"
  sha256 "REPLACE_WITH_RELEASE_ZIP_SHA256"

  url "https://github.com/YOUR_GITHUB_USER/prayer-times/releases/download/v#{version}/PrayerTimes-#{version}.zip"
  name "Prayer Times"
  desc "Menu bar app for Islamic prayer times"
  homepage "https://github.com/YOUR_GITHUB_USER/prayer-times"

  # Sparkle handles in-app updates; let Homebrew defer to it.
  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Prayer Times.app"

  zap trash: [
    "~/Library/Preferences/com.wedevs.prayertimes.plist",
    "~/Library/Caches/com.wedevs.prayertimes",
  ]
end
