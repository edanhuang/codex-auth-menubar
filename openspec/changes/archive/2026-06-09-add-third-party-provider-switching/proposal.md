## Why

当前应用只把 `codex-auth` 管理的官方 Codex 账号作为可切换对象，用户无法在同一个菜单里管理和切换第三方 API 配置。为了支持用户在官方账号和第三方供应商之间自由切换，需要把第三方 API 作为一种账号类型纳入现有菜单交互，同时安全地管理 `~/.codex/config.toml` 的写入与恢复。

## What Changes

- 在现有账号菜单中引入 Third Party 账号类型，与 Codex Auth 账号排列在同一个账号抽屉中。
- Third Party 账号展示用户录入的 API 备注名，并用绿色 `Third Party` 标签替代额度信息。
- 当前账号为 Third Party 时，主菜单 `Current Account` 后的标签展示供应商名称，隐藏主菜单中的 `5h` 和 `W` 额度行。
- `Add New Account...` 先让用户选择新增 Codex 账号或 Third Party 账号；Codex 账号沿用现有登录流程，Third Party 账号打开录入表单。
- Third Party 录入表单包含必填的 API 备注、Codex 供应商名称、API Key、请求地址、模型名称，以及可选官网链接和 endpoint 类型开关。
- 存在 Third Party 账号时，在 `Add New Account...` 下方展示 `Manage Third Party Account` 子菜单，允许编辑已录入的 Third Party 账号。
- 切换到 Third Party 账号时，应用写入用户级 `~/.codex/config.toml`，并临时将 `~/.codex/auth.json` 切换为 API Key 模式。
- 切换回 Codex Auth 账号时，应用按字段级恢复 `config.toml`，并恢复切换前完整备份的官方 `auth.json`。
- `Query Interval` 继续刷新 Codex Auth 账号额度；当前账号为 Third Party 时不展示第三方额度。
- 第一阶段只支持 OpenAI Responses API 兼容的第三方供应商；Chat Completions-only 供应商可保存但不能启用，直到本地路由能力实现。

## Capabilities

### New Capabilities

- `third-party-provider-switching`: 管理第三方 Codex Provider 账号，并在官方 Codex Auth 账号和第三方 Provider 配置之间切换。

### Modified Capabilities

无。

## Impact

- 影响 `Sources/main.m` 中的菜单构建、账号模型、账号切换和刷新展示逻辑。
- 新增 Third Party 账号持久化存储，API Key 应优先使用 macOS Keychain，非敏感字段使用应用配置文件或 `NSUserDefaults`。
- 新增对 `~/.codex/config.toml` 的字段级更新与恢复，以及对官方 `auth.json` 的私有备份和完整恢复逻辑。
- 需要确保现有 `codex-auth status/list/switch/login` 流程不被 Third Party 账号影响。
- README 需要补充 Third Party 账号配置、Responses API 限制、切换后需重启 Codex 会话等说明。
