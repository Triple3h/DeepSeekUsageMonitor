# DeepSeekUsageMonitor

macOS 菜单栏小工具，用于通过 DeepSeek 网页端接口快速查看余额和 Token 用量。

## 功能

- 使用网页端接口 `GET https://platform.deepseek.com/api/v0/users/get_user_summary` 查询余额、可用 Token 估算和本月费用。
- 使用网页端接口 `GET https://platform.deepseek.com/api/v0/usage/amount?month=...&year=...` 查询指定月份 Token 用量。
- 设置页保存平台 Bearer Token 和 Cookie，敏感信息写入 macOS Keychain，不写死在代码里。
- 设置页显示原始 JSON，方便后续按真实字段继续优化展示。

## 运行

```bash
cd /Users/triple3h/Documents/CodexProjects/DeepSeekUsageMonitor
swift run DeepSeekUsageMonitor
```

启动后在菜单栏点击折线图标，进入设置页填写：

- 平台 Bearer Token：从平台页面请求头 `authorization: Bearer ...` 中复制 Bearer 后面的值。
- Cookie：从抓包请求的 Cookie 中复制，通常平台内部接口需要。

## 注意

平台 `usage/amount` 和 `get_user_summary` 是网页内部接口，不属于官方公开 API。登录态过期后需要重新从浏览器抓取 Bearer Token/Cookie。
