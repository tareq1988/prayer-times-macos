# Releasing

Prayer Times ships via **GitHub Releases** (Sparkle auto-update) and a **Homebrew
Cask**. Builds are **universal (arm64 + x86_64), ad-hoc signed, and _not_
notarized** — first launch is right-click → Open. (We deliberately skip Apple
notarization, so no Apple Developer Program membership is required.)

There are **two paths, and they produce identical artifacts** — use whichever is
convenient:

- **Local** (`scripts/release-local.sh`) — default; faster on your Mac.
- **CI** (`.github/workflows/release.yml`) — manual-dispatch fallback for when you
  don't have a Mac handy. The repo is public, so macOS runner minutes are free.

Both do the same six things: build universal ad-hoc → zip → EdDSA-sign for Sparkle
→ regenerate & commit `docs/appcast.xml` → publish the GitHub Release (zip +
CHANGELOG notes) → bump the Homebrew cask. Same effort, same output.

## Cutting a release

1. Bump **`MARKETING_VERSION`** (and **`CURRENT_PROJECT_VERSION`**) in `project.yml`.
2. Add a dated section to **`CHANGELOG.md`** (it becomes the release notes).
3. Commit and push (e.g. `chore(release): prepare 0.5.1 (version bump + changelog)`).
4. Then **either** path:

```bash
# Local (default)
./scripts/release-local.sh 0.5.1          # creates the tag + release, bumps the cask

# CI (no Mac needed) — tag must exist first
git tag v0.5.1 && git push origin v0.5.1
gh workflow run release.yml -f tag=v0.5.1
```

> Use **one** path per version, not both — each creates the release and pushes the
> appcast, so running both would collide.

### Parity at a glance

| Step | Local script | CI workflow |
|---|---|---|
| Universal ad-hoc build + zip | ✅ | ✅ |
| EdDSA-sign + regenerate appcast | ✅ (key from keychain) | ✅ (key from `SPARKLE_ED_PRIVATE_KEY`) |
| Commit `docs/appcast.xml` to `main` | ✅ | ✅ |
| GitHub Release (zip + CHANGELOG notes) | ✅ | ✅ |
| Homebrew cask bump | ✅ (SSH to tap) | ✅ (needs `TAP_DEPLOY_KEY`; else prints values) |

## One-time setup

### Sparkle EdDSA keys
Run Sparkle's `generate_keys` once (the tools are auto-fetched into `.tools/sparkle`
by the local script):
```bash
.tools/sparkle/bin/generate_keys             # stores the private key in the login keychain (local path)
.tools/sparkle/bin/generate_keys -x ed_priv  # exports the private key to a file (for the CI secret)
```
- Put the **public** key in `Info.plist` → `SUPublicEDKey`.
- The **private** key stays in your keychain (local path) and is also stored as the
  `SPARKLE_ED_PRIVATE_KEY` repo secret (CI path). Never commit it.

### GitHub Pages (appcast hosting)
- Enable **GitHub Pages**, serving from `/docs` on `main`.
- Point `SUFeedURL` (`Info.plist`) at
  `https://tareq1988.github.io/prayer-times-macos/appcast.xml`.
- Both release paths regenerate and commit `docs/appcast.xml` each release; Pages
  serves it. (It is **not** attached as a release asset.)

### Homebrew tap
- The cask lives **only** in the tap repo `github.com/tareq1988/homebrew-tap`
  (`Casks/prayer-times.rb`) — single source of truth, no in-repo copy.
- Local: pushes the `version` + `sha256` bump over your SSH key automatically.
- CI: pushes the same bump over a `TAP_DEPLOY_KEY` deploy key (below).

### CI secrets (only for the GitHub Actions path)
Settings → Secrets and variables → Actions:

| Secret | Purpose |
|---|---|
| `SPARKLE_ED_PRIVATE_KEY` | Exported Sparkle EdDSA private key — EdDSA-signs the update. **Required** for CI. |
| `TAP_DEPLOY_KEY` | SSH **private** key of a write **deploy key** on `tareq1988/homebrew-tap` — lets CI bump the cask. Optional: without it the run still succeeds and prints the version + sha256 for a manual bump. |

The deploy key is scoped to the tap repo only (no PAT needed). Recreate it with:

```bash
ssh-keygen -t ed25519 -f tap_key -N "" -C "prayer-times-ci-cask-bump"
gh repo deploy-key add tap_key.pub --repo tareq1988/homebrew-tap --title "CI cask bump" --allow-write
gh secret set TAP_DEPLOY_KEY < tap_key
rm -f tap_key tap_key.pub
```

The CI workflow is **`workflow_dispatch` only** — it never runs automatically on a
tag, so it can't collide with a local release.

## Notes & gotchas
- **Xcode 26 required.** The app uses macOS 26 SDK APIs (Liquid Glass
  `.glassEffect`). The CI workflow selects the newest `Xcode_26*.app` on the runner
  and fails with a clear message if none is present.
- **Ad-hoc, not notarized.** Distributed builds are ad-hoc signed; users right-click
  → Open on first launch. If you later want notarization, switch the build to a
  Developer ID identity and add a `notarytool` step (and the Apple credentials).
- `CURRENT_PROJECT_VERSION` is the Sparkle build number — increment it every release
  alongside `MARKETING_VERSION`.

## License
This project is distributed under an OSS license (see `LICENSE`).
