# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS menu bar app (Swift/SwiftUI, SPM-based, no Xcode project) that monitors DeepSeek platform usage and balance by calling internal web endpoints. Sensitive credentials are stored in the macOS Keychain.

## Build & Run

```bash
# Build
swift build

# Run in development mode
swift run DeepSeekUsageMonitor

# Build release .app bundle (includes AppIcon)
./scripts/build-app.sh
# Then install: cp -r DeepSeekUsageMonitor.app /Applications/
```

There are currently no tests. If adding tests, use `swift test`.

### App Icon

Icons are generated from `Sources/DeepSeekUsageMonitor/Resources/deepseek-logo.pdf`:
- `Resources/AppIcon.icns` — pre-built icns for the .app bundle
- `Resources/Assets.xcassets/AppIcon.appiconset/` — 10 PNG sizes (16–512 @1x/@2x)
- `scripts/build-app.sh` compiles the asset catalog and copies `AppIcon.icns` into the bundle

To regenerate icons from a new source PDF/SVG, use `sips` to rasterize and `iconutil -c icns` to bundle.

## Architecture

### Module Split
- **`DeepSeekUsageMonitorCore`** (library): Network client, parsers, models, Keychain store, CSV parser, token estimator.
- **`DeepSeekUsageMonitor`** (executable target): SwiftUI app, views, window controllers, app delegate. Depends on Core.

### Key Components

**`MenuBarManager`** (`Sources/DeepSeekUsageMonitor/MenuBarManager.swift`)
Central `@MainActor` manager that owns the `NSStatusItem` and `FloatingPanel`. Handles panel show/hide, hover detection, auto-close timers, menu bar icon updates, and coordinates with `SettingsWindowController`. Created by `AppDelegate` on launch.

**`FloatingPanel`** (`Sources/DeepSeekUsageMonitor/FloatingPanel.swift`)
Custom `NSPanel` subclass with `.borderless` + `.fullSizeContentView` style mask. Transparent background with 16pt corner radius. Triple-layer corner radius clipping for proper material rendering. Does not hide on deactivate.

**`AppModel`** (`Sources/DeepSeekUsageMonitor/AppModel.swift`)
Central `@MainActor` `ObservableObject`. Owns `PlatformSummaryClient` and `KeychainStore`, manages all published UI state, and runs a background refresh loop (`startBackgroundRefresh`) based on the user-configured interval.

**`Theme`** (`Sources/DeepSeekUsageMonitor/Theme.swift`)
Centralized design system: brand colors (#4D6BFE), gradients, panel dimensions, card backgrounds (adapts to dark/light mode), font tokens, and `ViewModifier` helpers (`.themeCard()`, `.themeTint()`).

**`PlatformSummaryClient`** (`Sources/DeepSeekUsageMonitorCore/PlatformSummaryClient.swift`)
All network calls go through here. It hits three DeepSeek platform endpoints (internal web APIs, not the official public API):
- `GET /api/v0/users/get_user_summary` — balance and account summary
- `GET /api/v0/usage/amount?month=&year=` — token usage breakdown
- `GET /api/v0/usage/cost?month=&year=` — cost breakdown

Requests require a Bearer Token and Cookie copied from the browser. The client sets the appropriate headers (`Authorization`, `Cookie`, `Referer`, `X-App-Version`).

**`DashboardView`** (`Sources/DeepSeekUsageMonitor/DashboardView.swift`)
Main panel UI (380px wide). Assembles child components and owns data computation logic (display usage, chart data, cost calculation, model merging). Accepts an `onClose` closure for panel management.

**View Components** (`Sources/DeepSeekUsageMonitor/Views/`)
Modular view components extracted from DashboardView:
- `HeaderView` — Title bar with DS logo and refresh button
- `WarningBanner` — Balance warning notification
- `BalanceCardView` — Recharge balance and monthly cost cards
- `UsageSectionView` — Token usage with segmented picker, stat cards, chart, and model distribution
- `StatCardView` — Reusable stat card with accent bar
- `MiniChartView` — 7-day bar chart with cache hit ratio labels
- `ModelDistributionView` — Per-model usage rows with progress bars
- `FooterView` — Settings, console, and quit buttons
- Shared styles: `IconButtonStyle`, `FooterButtonStyle`

**`SettingsView`** (`Sources/DeepSeekUsageMonitor/SettingsView.swift`)
Shown in a separate floating `NSWindow` via `SettingsWindowController`. Contains credential inputs, refresh interval, balance warning threshold, launch-at-login toggle, and debug JSON disclosure groups.

**`KeychainStore`** (`Sources/DeepSeekUsageMonitorCore/KeychainStore.swift`)
Uses the macOS Security framework (`SecItemAdd`/`SecItemUpdate`/`SecItemCopyMatching`). Stores `platformBearerToken` and `platformCookie` under the service name `DeepSeekUsageMonitor`.

**`LaunchAtLoginManager`** (`Sources/DeepSeekUsageMonitor/LaunchAtLoginManager.swift`)
Writes or removes a `com.deepseekusagemonitor.launch.plist` in `~/Library/LaunchAgents/` and uses `launchctl load/unload` to enable or disable launch at login.

### Resource Loading
The app bundles a PDF icon (`deepseek-logo.pdf`) as an SPM resource. `MenuBarManager` contains fallback lookup logic that searches multiple candidate paths to find the resource, whether running as a raw executable or inside a `.app` bundle.

### Menu Bar Architecture
The app uses `NSStatusItem` + custom `FloatingPanel` (NSPanel subclass) instead of SwiftUI's `MenuBarExtra`. This provides:
- Custom panel positioning (centered below the status item, clamped to screen edges)
- Hover detection with auto-close pause (0.15s polling timer)
- Configurable auto-close behavior (5s default)
- Click-outside-to-close via `NSEvent.addGlobalMonitorForEvents`
- Animated panel resize when data loads
- Transparent background with custom corner radius (16pt)

## Important Notes

- The app calls **internal web endpoints** (`platform.deepseek.com/api/v0/...`). These are not official public APIs and may change without notice.
- Login state expires; users must re-copy Bearer Token and Cookie from browser dev tools when requests start failing.
- The project uses `Package.swift` only; there is no `.xcodeproj`.
- Platform target: macOS 13+.

## Subagent Model Convention

When using superpowers:subagent-driven-development:

- **Implementer subagents** for mechanical tasks (1-2 files, clear spec): use `model: haiku`
- **Spec reviewer** and **code quality reviewer** subagents: use default (inherit from parent), or `model: opus` for judgment-heavy reviews
