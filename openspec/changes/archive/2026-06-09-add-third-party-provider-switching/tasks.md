## 1. 数据模型与存储

- [x] 1.1 定义 Third Party 账号模型，包含账号 id、API 备注、Codex 供应商名称、官网链接、API 请求地址、endpoint 类型、模型名称、API 格式状态和 Keychain 标识。
- [x] 1.2 实现 Third Party 账号列表的读取、保存、更新和删除能力。
- [x] 1.3 使用 macOS Keychain 保存和读取 Third Party API Key，并在非敏感配置中只保存 Keychain item 标识。
- [x] 1.4 为 Third Party 账号生成稳定唯一的 Codex provider id，避免使用固定 `custom` 覆盖用户配置。

## 2. Codex 配置写入与恢复

- [x] 2.1 实现 `~/.codex/config.toml` 的读取、TOML 字符串转义和 section-aware 写入工具。
- [x] 2.2 实现切换 Third Party 前的字段级快照，记录应用会覆盖的 provider 相关字段原值。
- [x] 2.3 实现切换到 Responses-compatible Third Party 时写入 `model_provider`、`model` 和 `[model_providers.<id>]`。
- [x] 2.4 实现切回 Codex Auth 账号时的字段级恢复，原字段不存在时删除应用写入字段，并保留无关配置。
- [x] 2.5 阻止启用 Chat Completions-only Third Party 账号，并返回需要本地路由的用户提示。
- [x] 2.6 切换 Third Party 时备份官方 `auth.json` 并写入 API Key 模式，切回 Codex Auth 时恢复原始认证文件。

## 3. 菜单展示与账号切换

- [x] 3.1 扩展账号列表构建逻辑，将 Codex Auth 账号和 Third Party 账号合并展示。
- [x] 3.2 在账号抽屉中为 Third Party 账号展示 API 备注和绿色 `Third Party` 标签，不展示 5h/W 额度。
- [x] 3.3 当前账号为 Third Party 时，将 `Current Account` 标签展示为 Codex 供应商名称，并隐藏主菜单 5h/W 额度行。
- [x] 3.4 实现点击 Third Party 账号后的切换流程，包括配置写入、当前账号持久化、菜单刷新和重启 Codex 会话提示。
- [x] 3.5 保持 `Query Interval` 继续刷新 Codex Auth 账号额度，并确保当前 Third Party 展示不被定时刷新覆盖。

## 4. 新增与管理 Third Party 账号 UI

- [x] 4.1 将 `Add New Account...` 改为先弹出 Codex 账号和 Third Party 账号选择。
- [x] 4.2 Codex 账号选择继续调用现有登录流程。
- [x] 4.3 实现 Third Party 账号新增表单，包含 API 备注、Codex 供应商名称、官网链接、API Key、endpoint 类型、API 请求地址和模型名称。
- [x] 4.4 对 Third Party 表单必填字段做保存前校验，并展示缺失字段提示。
- [x] 4.5 当存在 Third Party 账号时展示 `Manage Third Party Account` 子菜单，并允许按 API 备注打开编辑表单。
- [x] 4.6 编辑 Third Party 账号后，同步更新账号列表展示；如果编辑的是当前账号，重新投影配置或提示需要重新切换。

## 5. 验证与文档

- [x] 5.1 增加配置写入/恢复相关测试或可重复验证脚本，覆盖原字段存在、原字段不存在和无关配置保留场景。
- [x] 5.2 验证 Third Party 当前态下主菜单不展示 5h/W，账号抽屉展示绿色 `Third Party` 标签。
- [x] 5.3 验证 Codex Auth 与 Third Party 之间可反复切换，且切回官方模式后 `codex-auth` 账号刷新和切换仍可用。
- [x] 5.4 验证 Chat Completions-only provider 可保存但不可启用，并展示需要本地路由的提示。
- [x] 5.5 更新 README，说明 Third Party 账号配置、Responses API 限制、Base URL 与 Full URL 区别、切换后需重启 Codex 会话。
- [x] 5.6 执行 `./build-app.sh`，确认 app 能成功编译打包。
