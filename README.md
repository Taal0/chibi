# Chibi

Native macOS desk pet (Swift + AppKit). Transparent overlay, APNG animations, terminal-style chat panel streaming from [personalLLM-api](https://github.com/Taal0/personalLLM-api).

**Faz 1:** complete — pet + chat + session + PC API.

## Quick start (development)

```bash
open ChibiNative.xcodeproj
# or
xcodebuild -project ChibiNative.xcodeproj -scheme ChibiNative -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/ChibiNative.app
```

Quit from the menu-bar tray icon (🐱).

## Install to Applications

```bash
chmod +x scripts/*.sh
./scripts/build-release.sh
./scripts/install.sh
```

`install.sh` quits a running Chibi, removes duplicate installs (`Chibi.app`, `ChibiNative.app`, …), installs to `/Applications/Chibi.app`, and relaunches.

Remove duplicates only:

```bash
./scripts/cleanup-duplicates.sh
```

Update from a GitHub release (after `gh auth login`):

```bash
./scripts/update-from-release.sh          # latest tag
./scripts/update-from-release.sh v1.0.0   # specific tag
```

## API URL

Default: `http://192.168.1.233:8000` (PC `personalLLM-api`).

Override (persists across updates — same bundle id):

```bash
defaults write com.talo.ChibiNative API_URL "http://your-pc-ip:8000"
```

## Release flow (CI/CD)

| Trigger | Workflow | Result |
| :--- | :--- | :--- |
| Push / PR to `main` | `ci.yml` | Verifies Release build |
| Tag `v*` (e.g. `v1.0.0`) | `release.yml` | GitHub Release + `ChibiNative-*.zip` |

Bump version in Xcode (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`), then:

```bash
git tag v1.0.0
git push origin v1.0.0
```

On your Mac: `./scripts/update-from-release.sh v1.0.0`

> **Note:** Builds are ad-hoc signed (no Apple Developer cert). Fine for personal use. First open after download may need `xattr -cr /Applications/Chibi.app` if Gatekeeper blocks it.

## Layout

```
ChibiNative/     Swift sources (App, Pet, Chat, API, …)
scripts/         build-release, install, cleanup-duplicates, generate-app-icon
.github/         CI + release workflows
```
