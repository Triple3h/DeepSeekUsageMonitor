# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

## Project Overview

macOS menu bar app (Swift/SwiftUI, SPM-only, no Xcode project) that monitors DeepSeek platform usage and balance by calling internal web endpoints. Credentials stored in macOS Keychain.

## Build & Run

```bash
# Development build & run
swift build
swift run DeepSeekUsageMonitor

# Release .app bundle (ad-hoc signed, version injected from VERSION file)
./scripts/build-app.sh

# Release DMG (calls build-app.sh internally, optional filename arg)
./scripts/build-dmg.sh                    # outputs DeepSeekUsageMonitor.dmg
./scripts/build-dmg.sh "MyCustom.dmg"     # outputs MyCustom.dmg

# Tests (none currently)
swift test
```

Debug mode reads Bearer Token from env var `DEEPSEEK_BEARER` if Keychain is empty.

## Versioning & Release

`VERSION` file at repo root is the single source of truth for semver (e.g. `1.0.0`).

- `build-app.sh` reads `VERSION` and injects it into `CFBundleShortVersionString` in the bundled Info.plist
- Pushing to `main` triggers `.github/workflows/release.yml` on `macos-14` runner
- Workflow creates tag `v{VERSION}`, builds DMG named `DeepSeekUsageMonitor-v{VERSION}.dmg`, and publishes a GitHub Release
- If the tag already exists, the workflow skips (no duplicate releases)
- To release: bump `VERSION` (e.g. `1.0.0` → `1.0.1` for patches, `1.0.1` → `1.1.0` for features) and push

## Architecture

### Module Split (SPM)

- **`DeepSeekUsageMonitorCore`** (library): `PlatformSummaryClient` (network), `KeychainStore`, `UsageCSVParser`, `TokenEstimator`, `UsageCacheStore`, `Models`
- **`DeepSeekUsageMonitor`** (executable, depends on Core): SwiftUI app, views, window controllers. Bundles `Resources/deepseek-logo.pdf` as SPM resource

### App Lifecycle

`DeepSeekUsageMonitorApp` → `AppDelegate` → creates `MenuBarManager` → owns `NSStatusItem` + `FloatingPanel` (custom `NSPanel` subclass). Does NOT use SwiftUI's `MenuBarExtra`.

### Key Actors

- **`AppModel`** (`@MainActor ObservableObject`): owns all UI state, `PlatformSummaryClient`, `KeychainStore`, `UsageCacheStore`, and the background refresh loop
- **`MenuBarManager`** (`@MainActor`): owns `NSStatusItem` and `FloatingPanel`, handles show/hide, hover detection (0.15s polling), auto-close (5s default), click-outside-to-close, and coordinates `SettingsWindowController`
- **`FloatingPanel`**: borderless `NSPanel` with transparent background, 16pt corner radius, triple-layer clipping for material rendering

### Data Flow

`AppModel` → `PlatformSummaryClient` (3 internal endpoints at `platform.deepseek.com/api/v0/...`) → results published to SwiftUI views. `UsageCacheStore` caches to disk (1h for current month, 7d for history). `KeychainStore` persists bearer token via macOS Security framework.

### UI Structure

`DashboardView` (380px wide) assembles: `HeaderView` → `WarningBanner` → `BalanceCardView` → `UsageSectionView` (with `StatCardView`, `MiniChartView`, `ModelDistributionView`) → `FooterView`. Settings shown in separate floating window via `SettingsWindowController`.

### Design System

`Theme.swift` centralizes brand colors (#4D6BFE), gradients, panel dimensions, card backgrounds (dark/light adaptive), font tokens, and `ViewModifier` helpers (`.themeCard()`, `.themeTint()`).

## Important Notes

- Endpoints are **internal web APIs** (`platform.deepseek.com/api/v0/...`), not official public APIs — may change without notice
- Login state expires; users must re-copy Bearer Token from browser dev tools
- No `.xcodeproj` — pure `Package.swift` project, macOS 13+ target
- `LaunchAtLoginManager` writes a launchd plist to `~/Library/LaunchAgents/`
