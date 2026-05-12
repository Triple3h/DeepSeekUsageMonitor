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

# Build release .app bundle
./scripts/build-app.sh
# Then install: cp -r DeepSeekUsageMonitor.app /Applications/
```

There are currently no tests. If adding tests, use `swift test`.

## Architecture

### Module Split
- **`DeepSeekUsageMonitorCore`** (library): Network client, parsers, models, Keychain store, CSV parser, token estimator.
- **`DeepSeekUsageMonitor`** (executable target): SwiftUI app, views, window controllers, app delegate. Depends on Core.

### Key Components

**`AppModel`** (`Sources/DeepSeekUsageMonitor/AppModel.swift`)
Central `@MainActor` `ObservableObject`. Owns `PlatformSummaryClient` and `KeychainStore`, manages all published UI state, and runs a background refresh loop (`startBackgroundRefresh`) based on the user-configured interval.

**`PlatformSummaryClient`** (`Sources/DeepSeekUsageMonitorCore/PlatformSummaryClient.swift`)
All network calls go through here. It hits three DeepSeek platform endpoints (internal web APIs, not the official public API):
- `GET /api/v0/users/get_user_summary` — balance and account summary
- `GET /api/v0/usage/amount?month=&year=` — token usage breakdown
- `GET /api/v0/usage/cost?month=&year=` — cost breakdown

Requests require a Bearer Token and Cookie copied from the browser. The client sets the appropriate headers (`Authorization`, `Cookie`, `Referer`, `X-App-Version`).

**`DashboardView`** (`Sources/DeepSeekUsageMonitor/DashboardView.swift`)
Main menu bar popover UI (340px wide). Displays balance, token usage, cost, and a mini bar chart. Supports toggling between "today" and "month" views and navigating months.

**`SettingsView`** (`Sources/DeepSeekUsageMonitor/SettingsView.swift`)
Shown in a separate floating `NSWindow` via `SettingsWindowController`. Contains credential inputs, refresh interval, balance warning threshold, launch-at-login toggle, and debug JSON disclosure groups.

**`KeychainStore`** (`Sources/DeepSeekUsageMonitorCore/KeychainStore.swift`)
Uses the macOS Security framework (`SecItemAdd`/`SecItemUpdate`/`SecItemCopyMatching`). Stores `platformBearerToken` and `platformCookie` under the service name `DeepSeekUsageMonitor`.

**`LaunchAtLoginManager`** (`Sources/DeepSeekUsageMonitor/LaunchAtLoginManager.swift`)
Writes or removes a `com.deepseekusagemonitor.launch.plist` in `~/Library/LaunchAgents/` and uses `launchctl load/unload` to enable or disable launch at login.

### Resource Loading
The app bundles a PDF icon (`deepseek-logo.pdf`) as an SPM resource. `DeepSeekUsageMonitorApp.swift` contains fallback lookup logic that searches multiple candidate paths to find the resource, whether running as a raw executable or inside a `.app` bundle.

## Important Notes

- The app calls **internal web endpoints** (`platform.deepseek.com/api/v0/...`). These are not official public APIs and may change without notice.
- Login state expires; users must re-copy Bearer Token and Cookie from browser dev tools when requests start failing.
- The project uses `Package.swift` only; there is no `.xcodeproj`.
- Platform target: macOS 13+.
