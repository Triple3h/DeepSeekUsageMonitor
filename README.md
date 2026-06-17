# DeepSeekUsageMonitor

macOS 菜单栏小工具，用于监控 **DeepSeek** 和 **MIMO** 平台的余额与 Token 用量。

## 功能

- **多平台支持**：同时监控 DeepSeek 和 MIMO 两个平台。
- **余额监控**：实时显示各平台账户余额、可用 Token 估算和本月费用。
- **用量分析**：按模型、按日期展示 Token 用量分布，支持折线图可视化。
- **计费模式**：MIMO 支持按量收费和 Token Plan 两种模式。
- **预警系统**：余额低于阈值时在菜单栏和面板中显示预警，可按平台、按计费模式独立开关。
- **主题切换**：支持跟随系统 / 深色 / 浅色三种主题模式。
- **自动刷新**：后台定时刷新数据，可自定义刷新间隔。
- **登录时启动**：可选开机自动启动。
- **凭证安全**：Bearer Token / Cookie 写入 macOS Keychain，不写死在代码里。

## 运行

```bash
# Development build & run
swift build
swift run DeepSeekUsageMonitor

# Release .app bundle
./scripts/build-app.sh

# Release DMG
./scripts/build-dmg.sh
```

启动后在菜单栏点击图标，进入设置页填写：

- **DeepSeek**：从 `platform.deepseek.com` 页面请求头 `authorization: Bearer ...` 中复制 Token。
- **MIMO**：从 `platform.xiaomimimo.com` 页面请求头 `Cookie` 中复制完整字符串。

## 注意

DeepSeek 和 MIMO 的接口均为网页内部接口，不属于官方公开 API。登录态过期后需要重新从浏览器抓取凭证。