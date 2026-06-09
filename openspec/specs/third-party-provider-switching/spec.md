# third-party-provider-switching Specification

## Purpose
定义 Third Party Codex provider 账号的录入、存储、展示、切换及官方认证恢复行为，使用户可以在 Codex Auth 账号与 Responses API 兼容的第三方接口之间安全切换。
## Requirements
### Requirement: Third Party accounts SHALL appear in the account menu
系统 SHALL 将 Third Party 账号与 Codex Auth 账号展示在同一个账号抽屉中，并允许用户从该抽屉选择当前账号。

#### Scenario: Display mixed account list
- **WHEN** 用户已配置 Codex Auth 账号和至少一个 Third Party 账号
- **THEN** 账号抽屉同时展示 Codex Auth 账号和 Third Party 账号
- **AND** Third Party 账号使用用户录入的 API 备注作为显示名称
- **AND** Third Party 账号额度区域显示绿色 `Third Party` 标签

#### Scenario: Select third party account
- **WHEN** 用户在账号抽屉中点击 Third Party 账号
- **THEN** 系统将该 Third Party 账号设为当前账号
- **AND** 系统触发 Codex provider 配置写入流程

### Requirement: Current Account area SHALL adapt to Third Party accounts
系统 SHALL 根据当前账号类型调整主菜单 `Current Account` 区域展示。

#### Scenario: Current account is Codex Auth
- **WHEN** 当前账号是 Codex Auth 账号
- **THEN** `Current Account` 后的标签展示 `codex-auth` 返回的账号类型或 plan
- **AND** 主菜单展示 5h 和 W 额度行

#### Scenario: Current account is Third Party
- **WHEN** 当前账号是 Third Party 账号
- **THEN** `Current Account` 后的标签展示用户录入的 Codex 供应商名称
- **AND** 当前账号名称展示用户录入的 API 备注
- **AND** 主菜单不展示 5h 和 W 额度行

### Requirement: Add New Account SHALL branch by account type
系统 SHALL 在用户点击 `Add New Account...` 后让用户选择新增 Codex 账号或 Third Party 账号。

#### Scenario: Add Codex account
- **WHEN** 用户在新增账号弹窗中选择 Codex 账号
- **THEN** 系统沿用现有 Codex 登录流程

#### Scenario: Add Third Party account
- **WHEN** 用户在新增账号弹窗中选择 Third Party 账号
- **THEN** 系统打开 Third Party 账号录入表单

### Requirement: Third Party account form SHALL collect required provider fields
系统 SHALL 要求用户录入启用 Third Party Codex provider 所需的字段，并校验必填项。

#### Scenario: Save valid Third Party account
- **WHEN** 用户填写 API 备注、Codex 供应商名称、API Key、API 请求地址、模型名称，并选择 endpoint 类型
- **THEN** 系统保存 Third Party 账号
- **AND** 官网链接为空时不阻止保存

#### Scenario: Reject missing required fields
- **WHEN** 用户缺少 API 备注、Codex 供应商名称、API Key、API 请求地址、模型名称或 endpoint 类型任一必填字段
- **THEN** 系统阻止保存
- **AND** 系统提示缺失字段

### Requirement: Manage Third Party Account SHALL be shown only when needed
系统 SHALL 仅在存在 Third Party 账号时展示 `Manage Third Party Account` 菜单，并允许编辑已保存账号。

#### Scenario: No Third Party account exists
- **WHEN** 用户未保存任何 Third Party 账号
- **THEN** 主菜单不展示 `Manage Third Party Account`

#### Scenario: Edit existing Third Party account
- **WHEN** 用户在 `Manage Third Party Account` 子菜单中点击某个 API 备注
- **THEN** 系统打开该 Third Party 账号的编辑表单
- **AND** 保存后系统使用更新后的字段参与后续展示和切换

### Requirement: Switching to Third Party SHALL write user-level Codex config
系统 SHALL 在切换到 Third Party 账号时写入用户级 `~/.codex/config.toml` 和 API Key 模式的 `~/.codex/auth.json`，使 Codex 使用该 Third Party provider 并显示 API Key 认证模式。

#### Scenario: Write Responses-compatible provider config
- **WHEN** 用户切换到 Responses API 兼容的 Third Party 账号
- **THEN** 系统将 `model_provider` 设置为该账号的唯一 provider id
- **AND** 系统写入对应 `[model_providers.<id>]` 表
- **AND** provider 表包含供应商名称、请求地址、`wire_api = "responses"` 和认证要求
- **AND** `auth.json` 仅包含当前 Third Party 账号的 `OPENAI_API_KEY`
- **AND** 系统提示用户重启 Codex 会话以重新读取配置

#### Scenario: Preserve unrelated Codex config
- **WHEN** `~/.codex/config.toml` 中存在 MCP、sandbox、permissions、profiles 或其他无关配置
- **THEN** 系统写入 Third Party provider 时保留这些无关配置

### Requirement: Switching to Codex Auth SHALL restore official config fields
系统 SHALL 在用户从 Third Party 切回 Codex Auth 账号时恢复官方模式，恢复原始官方 `auth.json`，并只恢复应用切换 Third Party 时覆盖过的 Codex 配置字段。

#### Scenario: Restore previous official fields
- **WHEN** 用户从 Third Party 账号切换到 Codex Auth 账号
- **THEN** 系统恢复切换前记录的 Codex provider 相关字段原值
- **AND** 系统恢复切换前完整备份的官方 `auth.json`
- **AND** 系统保留切换期间用户新增或修改的无关配置

#### Scenario: Remove fields that did not previously exist
- **WHEN** 用户切换到 Third Party 前某个被应用写入的 Codex provider 字段不存在
- **THEN** 切回 Codex Auth 账号时系统删除该字段

### Requirement: Query Interval SHALL refresh only Codex Auth usage
系统 SHALL 保持 `Query Interval` 定时刷新能力，但该刷新仅更新 Codex Auth 账号状态和额度。

#### Scenario: Current account is Third Party during refresh
- **WHEN** 当前账号是 Third Party 且定时刷新触发
- **THEN** 系统刷新 Codex Auth 账号状态和额度缓存
- **AND** 系统不请求 Third Party 余额或额度
- **AND** 系统不在当前 Third Party 展示中显示 5h 或 W 额度

### Requirement: Chat Completions-only providers SHALL not be enabled in initial release
系统 SHALL 在第一阶段阻止启用仅支持 Chat Completions 的 Third Party provider，并提示需要本地路由能力。

#### Scenario: Save Chat Completions-only provider
- **WHEN** 用户录入或编辑一个标记为 Chat Completions-only 的 Third Party provider
- **THEN** 系统允许保存该账号
- **AND** 系统在账号展示中标明该账号当前不可启用或需要本地路由

#### Scenario: Attempt to enable Chat Completions-only provider
- **WHEN** 用户尝试切换到 Chat Completions-only provider
- **THEN** 系统阻止切换
- **AND** 系统提示该 provider 需要本地路由，当前版本仅支持 Responses API 兼容 provider
