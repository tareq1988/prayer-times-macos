# Releasing

Prayer Times ships via **GitHub Releases** (Sparkle auto-update) and a **Homebrew
Cask**. The pipeline (`.github/workflows/release.yml`) runs on a version tag and
produces a universal, Developer-ID-signed, notarized, stapled, EdDSA-signed build.

## One-time setup

### 1. Apple Developer ID
- Join the Apple Developer Program.
- Create a **Developer ID Application** certificate; export it as a `.p12`.
- Create an **app-specific password** for `notarytool` (appleid.apple.com).
- Note your **Team ID** (10 chars).

### 2. Sparkle EdDSA keys
Run Sparkle's `generate_keys` once (from a Sparkle release tarball):
```bash
./bin/generate_keys            # stores the private key in the login keychain
./bin/generate_keys -x ed_priv # exports the private key to a file (for CI)
```
- Put the **public** key in `Info.plist` → `SUPublicEDKey`.
- Keep the **private** key for the `SPARKLE_ED_PRIVATE_KEY` secret. Never commit it.

### 3. Repo secrets (Settings → Secrets and variables → Actions)
| Secret | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i DeveloperID.p12` |
| `P12_PASSWORD` | the `.p12` password |
| `KEYCHAIN_PASSWORD` | any temp string for the CI keychain |
| `APPLE_TEAM_ID` | your Team ID |
| `AC_NOTARY_APPLE_ID` | Apple ID email |
| `AC_NOTARY_PASSWORD` | app-specific password |
| `SPARKLE_ED_PRIVATE_KEY` | exported Sparkle private key |

### 4. Hosting the appcast
- Point `SUFeedURL` (Info.plist) at `https://<user>.github.io/prayer-times/appcast.xml`.
- Enable **GitHub Pages** for the repo, serving from `/docs` on `main`.
- The workflow commits the regenerated `docs/appcast.xml` each release.

### 5. Info.plist placeholders to replace
- `SUPublicEDKey` → your Sparkle public key.
- `SUFeedURL` → your appcast URL.

### 6. Homebrew tap
- Create a tap repo `github.com/<you>/homebrew-tap`.
- Copy `Casks/prayer-times.rb` there and fill `url` / `homepage`.
- Each release prints the new `version` + `sha256` (workflow log) — bump the cask
  (or automate with a PAT).

## Cutting a release
```bash
# bump MARKETING_VERSION in project.yml, commit, then:
git tag v0.1.0
git push origin v0.1.0
```
The workflow builds, signs, notarizes, staples, EdDSA-signs, updates the appcast,
and publishes the GitHub Release with the zip. Sparkle clients pick it up; Homebrew
users get it after the cask bump.

## License
This project is distributed under an OSS license (see `LICENSE`).
