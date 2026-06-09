## Context

当前应用是一个 macOS 菜单栏工具，主要通过 `codex-auth` CLI 获取官方 Codex 账号状态、额度和切换能力。第三方供应商不属于 `codex-auth` 管理范围，切换第三方接口需要管理用户级 `~/.codex/config.toml`，同时不能破坏用户已有的 Codex 配置和官方登录状态。

OpenAI Codex 的 provider 配置属于用户级配置，不能依赖项目级 `.codex/config.toml`。因此 Third Party 账号切换必须被视为“修改本机 Codex 全局 provider 配置”的操作，而不是普通账号切换命令。

## Goals / Non-Goals

**Goals:**

- 将 Third Party API 作为账号类型接入现有菜单，而不是引入完全独立的模式入口。
- 支持新增、展示、编辑和切换 Third Party 账号。
- Third Party 账号展示 API 备注名和绿色 `Third Party` 标签，不展示 5h/W 额度。
- 当前账号为 Third Party 时，`Current Account` 标签展示供应商名称，并隐藏主菜单额度行。
- 切换 Third Party 时写入 `~/.codex/config.toml`，让 Codex 使用对应 provider。
- 切回 Codex Auth 账号时按字段级恢复官方模式，保留用户无关配置。
- `Query Interval` 继续刷新 Codex Auth 账号额度，不负责刷新 Third Party 额度。

**Non-Goals:**

- 不实现 Third Party 余额、额度或用量查询。
- 不实现本地路由或 Responses 与 Chat Completions 的协议转换。
- 不支持启用 Chat Completions-only provider；这类 provider 可保存但必须阻止切换并提示需要本地路由。
- 不修改 `codex-auth` CLI，也不让 `codex-auth` 管理 Third Party 账号。

## Decisions

### Third Party 账号作为账号列表的一等项展示

Third Party 账号会和 Codex Auth 账号排在同一个账号抽屉中，点击即可切换。这样符合当前应用的菜单心智：用户是在“切当前 Codex 使用的账号/接口”，不是在配置一个独立系统。

备选方案是新增 `Provider Mode` 顶层菜单，但这会迫使用户先理解模式，再理解账号，且会把当前账号显示和实际 Codex provider 状态拆开。当前设计更直接。

### Third Party 元数据与 API Key 分离存储

Third Party 非敏感字段存储在应用自己的配置中，例如 `~/Library/Application Support/CodexAuthMenu/third-party-accounts.json`。API Key 优先存储到 macOS Keychain，配置文件仅保存 Keychain item 标识。

这样避免在应用自己的配置文件中保存 API Key 明文。切换 Third Party 时，应用仍需将当前 Key 临时投影到 `~/.codex/auth.json` 的 `OPENAI_API_KEY`，使 Codex Desktop 将当前认证模式识别为 API Key，而不是继续沿用官方 ChatGPT 登录态。

### 使用唯一 provider id 写入 Codex 配置

每个 Third Party 账号生成稳定唯一的 provider id，例如 `codex_auth_menu_<uuid片段>`。切换时写入：

```toml
model_provider = "codex_auth_menu_xxxxxx"
model = "<model>"
model_reasoning_effort = "high"
disable_response_storage = true

[model_providers.codex_auth_menu_xxxxxx]
name = "<provider name>"
base_url = "<endpoint>"
wire_api = "responses"
requires_openai_auth = true
```

不使用固定 `custom`，避免覆盖用户已有的自定义 provider。

### Third Party 模式临时替换 auth.json

首次从官方账号切换到 Third Party 前，应用将原始 `~/.codex/auth.json` 原样备份到应用私有目录，并以 `0600` 权限保存。Third Party 激活期间，live `auth.json` 只包含当前账号的 `OPENAI_API_KEY`，与 `cc-switch` 默认的 API Key 切换行为一致。

只在 `config.toml` 写 `experimental_bearer_token` 虽然可以为请求提供 token，但 Codex Desktop 仍会从原 `auth.json` 的 `auth_mode = "chatgpt"` 判断 UI 认证状态，因此不能满足“显示 API Key 模式”的产品要求。

### 切回官方模式采用配置字段恢复与认证文件恢复

应用在首次切换到 Third Party 前记录自己将要覆盖的 Codex 字段原值，包括顶层 `model_provider`、`model`、`model_reasoning_effort`、`disable_response_storage`，以及当前会被激活或替换的 provider 表。切回 Codex Auth 账号时只恢复这些字段；如果原字段不存在，则删除应用写入的字段。

不采用整文件备份恢复，因为 `config.toml` 可能同时包含 MCP、sandbox、permissions、profiles 等用户手动配置。整文件恢复会误删用户在 Third Party 使用期间新增或修改的无关配置。

`auth.json` 不做字段级合并，而是恢复切换前的原始文件，因为它包含官方 OAuth token、刷新状态和账号模式，必须保持完整一致。

### Base URL 与 Full URL 只控制路径拼接，不解决协议转换

`Base URL` 表示服务根地址，应用或 Codex 按 Responses API 约定拼接 `/v1/responses` 或等效路径。`Full URL` 表示用户输入完整 endpoint，应用不再拼接路径。

如果供应商只支持 Chat Completions，Base URL 和 Full URL 都不能让它变成 Responses-compatible。第一阶段必须阻止这类账号启用，提示需要本地路由。

### Third Party 当前态不影响 Codex Auth 后台刷新

`Query Interval` 保持现有语义：定时刷新 `codex-auth status/list`。当前选中 Third Party 时，刷新结果只更新官方账号列表缓存，不改变当前 Third Party 显示，也不展示 Third Party 额度。

## Risks / Trade-offs

- [Risk] Codex 正在运行的会话可能已经读取旧配置，切换后不会立即生效。→ 切换成功后提示用户重启 Codex 会话。
- [Risk] `~/.codex/config.toml` 格式复杂，字符串拼接容易破坏用户配置。→ 使用 section-aware 编辑、TOML 字符串转义和可重复的写入/恢复验证，避免重写无关配置。
- [Risk] Third Party 激活期间 API Key 会以明文存在于 `~/.codex/auth.json`。→ 长期存储仍使用 Keychain，live auth 文件权限固定为 `0600`，README 说明安全边界。
- [Risk] 用户录入 DeepSeek/Kimi 等 Chat Completions provider 后期望可用。→ 表单和切换时明确第一阶段只支持 Responses API，Chat-only provider 保存后标记不可启用。
- [Risk] 切回官方模式未恢复干净会影响 `codex-auth` 官方账号。→ 字段级恢复逻辑需要覆盖“原字段存在/不存在”“Third Party provider 表存在/不存在”“多次 Third Party 之间切换”等场景。
