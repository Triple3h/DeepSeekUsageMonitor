# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

## Project Overview

macOS menu bar app (Swift/SwiftUI, SPM-only, no Xcode project) that monitors DeepSeek & MIMO platform usage and balance by calling internal web endpoints. Credentials stored in macOS Keychain.

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

`VERSION` file at repo root is the single source of truth for semver (e.g. `1.1.0`).

- `build-app.sh` reads `VERSION` and injects it into `CFBundleShortVersionString` in the bundled Info.plist
- Pushing to `master` triggers `.github/workflows/release.yml` on `macos-14` runner
- Workflow creates tag `v{VERSION}`, builds DMG named `DeepSeekUsageMonitor-v{VERSION}.dmg`, and publishes a GitHub Release
- If the tag already exists, the workflow skips (no duplicate releases)
- To release: bump `VERSION` (e.g. `1.0.0` → `1.0.1` for patches, `1.0.1` → `1.1.0` for features) and push

## Architecture

### Module Split (SPM)

- **`DeepSeekUsageMonitorCore`** (library): `PlatformSummaryClient` (DeepSeek network), `MimoClient` (MIMO network), `KeychainStore`, `UsageCSVParser`, `TokenEstimator`, `UsageCacheStore`, `Models`
- **`DeepSeekUsageMonitor`** (executable, depends on Core): SwiftUI app, views, window controllers. Bundles `Resources/deepseek-logo.png` and `mimo-logo.png` as SPM resources

### App Lifecycle

`DeepSeekUsageMonitorApp` → `AppDelegate` → creates `MenuBarManager` → owns `NSStatusItem` + `FloatingPanel` (custom `NSPanel` subclass). Does NOT use SwiftUI's `MenuBarExtra`.

### Key Actors

- **`AppModel`** (`@MainActor ObservableObject`): owns all UI state, `PlatformSummaryClient`, `KeychainStore`, `UsageCacheStore`, and the background refresh loop
- **`MenuBarManager`** (`@MainActor`): owns `NSStatusItem` and `FloatingPanel`, handles show/hide, hover detection (0.15s polling), auto-close (5s default), click-outside-to-close, and coordinates `SettingsWindowController`
- **`FloatingPanel`**: borderless `NSPanel` with transparent background, 16pt corner radius, triple-layer clipping for material rendering

### Data Flow

`AppModel` → `PlatformSummaryClient` (3 internal endpoints at `platform.deepseek.com/api/v0/...`) for DeepSeek, `MimoClient` (5 endpoints at `platform.xiaomimimo.com/api/v1/...`) for MIMO → results published to SwiftUI views. `UsageCacheStore` caches to disk (1h for current month, 7d for history). `KeychainStore` persists bearer token via macOS Security framework.

### UI Structure

`DashboardView` (380px wide) assembles: `HeaderView` → `WarningBanner` → `BalanceCardView` → `UsageSectionView` (with `StatCardView`, `MiniChartView`, `ModelDistributionView`) → `FooterView`. Settings shown in separate floating window via `SettingsWindowController`.

### Design System

`Theme.swift` centralizes brand colors (#4D6BFE), gradients, panel dimensions, card backgrounds (dark/light adaptive), font tokens, and `ViewModifier` helpers (`.themeCard()`, `.themeTint()`). `AppThemeMode` enum supports system/dark/light theme switching.

### Warning System & Extensibility

预警系统采用 **协议 + 枚举 + 泛型视图** 架构，支持按平台、按计费模式独立开关，扩展时无需改动通用逻辑。

**核心协议** `WarningLabelProvider`（定义于 `Models.swift`）：
- 约束：`CaseIterable + Hashable + RawRepresentable where RawValue == String`
- 要求实现：`var warningLabel: String { get }`
- 所有支持独立预警开关的计费模式枚举必须遵循此协议

**通用视图** `WarningToggles<T: WarningLabelProvider>`（定义于 `Views/WarningToggles.swift`）：
- 接收 `@Binding var selectedModes: Set<T>`
- 自动遍历 `T.allCases` 渲染各模式的独立 checkbox
- SettingsView 中 DeepSeek / Mimo 各只需一行 `WarningToggles(selectedModes: $model.xxxWarningModes)`

**持久化** `AppModel` 中通过泛型方法实现：
```swift
private static func loadWarningModes<T: WarningLabelProvider>(_:key:) -> Set<T>
private static func saveWarningModes<T: WarningLabelProvider>(_:key:)
```
各平台调用时只需指定类型和 UserDefaults key，无需重复序列化逻辑。

### New Platform Onboarding Checklist

接入新平台时的完整步骤：

1. **Models.swift** — 定义平台计费模式枚举，遵循 `WarningLabelProvider`，实现 `warningLabel`
2. **Models.swift** — 定义平台数据模型（余额、用量、概览等响应结构体）
3. **Core 层** — 创建 `XxxClient` 网络客户端，实现各 API 端点调用
4. **AppModel.swift** — 添加 `@Published var xxxEnabled`、`@Published var xxxWarningModes: Set<XxxBillingMode>` 等状态属性
5. **AppModel.swift** — 在 `isAnyBalanceWarning` 中添加该平台的预警判断逻辑
6. **AppModel.swift** — 在 `loadSavedCredentials()` / `saveSettings()` 中添加持久化（在 `StoredCredentials` 结构体中新增字段，利用泛型 `loadWarningModes` / `saveWarningModes`）
7. **AppModel.swift** — 在 `refreshBalance()` / `refreshPlatformData()` 中添加数据拉取逻辑
8. **SettingsView.swift** — 添加平台凭证输入区 + `WarningToggles(selectedModes: $model.xxxWarningModes)`
9. **BalanceCardView.swift** — 添加平台行数据构建（`PlatformBalanceRow`）
10. **MenuBarManager.swift** — 在 `menuBarBalanceText` 中添加菜单栏展示文本
11. **Resources/** — 添加平台 Logo（PNG，被 `PlatformRowView` 加载）

**注意事项：**
- 新增计费模式只需在已有枚举中加 case + 补 `warningLabel`，预警开关、持久化、UI 自动生效
- 平台 Logo 文件名需唯一，存放在 `Sources/DeepSeekUsageMonitor/Resources/`，通过 `Bundle.module` 加载
- MIMO 平台 API 请求需携带 `api-platform_ph` 查询参数（见常见问题经验）
- 所有平台凭证统一存储在 **单个 Keychain 条目**（`StoredCredentials` JSON），新增平台只需在 `StoredCredentials` 结构体中添加字段，不要新建独立的 Keychain 条目（避免多次授权弹窗）
- `Platform` 枚举（AppModel 内）控制 UI 平台切换器的显示项，新平台需添加对应 case

## Important Notes

- Endpoints are **internal web APIs** (`platform.deepseek.com/api/v0/...`), not official public APIs — may change without notice
- Login state expires; users must re-copy Bearer Token from browser dev tools
- No `.xcodeproj` — pure `Package.swift` project, macOS 13+ target
- `LaunchAtLoginManager` writes a launchd plist to `~/Library/LaunchAgents/`
