# CodexAuthMenu

Minimal macOS menu bar app for managing Codex Auth accounts and Third Party Codex providers.

The app supports both:

- Codex Auth accounts managed by the upstream [Loongphy/codex-auth](https://github.com/Loongphy/codex-auth) CLI.
- Multiple Third Party provider accounts stored locally and switched by updating the user-level Codex provider configuration.

This repository does not include or reimplement `codex-auth`. Official account status, usage, login, and switching still depend on the upstream CLI.

## Features

- Poll `codex-auth status` and `codex-auth list` on launch and then every `1/5/10/20/30/60` minutes
- Show active account, 5h usage, weekly usage, and service status
- Confirm before switching accounts from the menu bar
- Enable or disable auto-switching
- Send a macOS notification when 5h or weekly usage reaches 90%+
- Open the raw CLI status in Terminal
- Choose whether CLI calls use `Direct` networking or the macOS `System Proxy`
- Store and switch multiple Third Party Codex provider accounts that are compatible with the OpenAI Responses API
- Keep each Third Party API Key isolated in macOS Keychain

## Requirements

- macOS 13+
- Xcode Command Line Tools with `clang`
- Node.js 22+
- `codex-auth` CLI installed and initialized

Install Xcode Command Line Tools if `clang` is missing:

```bash
xcode-select --install
```

## 1. Install Node.js 22+

`codex-auth` requires Node.js 22 or newer. Verify the Node version that will run from your login shell:

```bash
zsh -l -c 'node -v'
```

If the version is lower than 22, install or switch to a newer Node.js before continuing.

## 2. Install `codex-auth` CLI

This app will not work until the upstream CLI is installed. Install it globally:

```bash
npm install -g @loongphy/codex-auth
```

Then verify it can be found from a login shell:

```bash
zsh -l -c 'command -v codex-auth'
zsh -l -c 'codex-auth --version'
```

## 3. Initialize `codex-auth`

Log in or import accounts with the upstream CLI first:

```bash
codex-auth login
```

Before launching the menu bar app, confirm these commands work in Terminal:

```bash
codex-auth status
codex-auth list
```

If either command fails, fix the CLI setup first. The app depends on these commands for all account and usage data.

## 4. Build the App

From this repository root:

```bash
./build-app.sh
```

The build script compiles the Objective-C source with `clang`, creates `CodexAuthMenu.app`, and packages the icon/resources.

## 5. Launch the App

```bash
open ./CodexAuthMenu.app
```

The app runs as a menu bar item. It does not show a Dock icon.

## Proxy Mode

The menu contains a `Proxy Mode` submenu near `Query Interval`:

- `Direct`: default. CLI calls do not inherit `HTTP_PROXY`, `HTTPS_PROXY`, or `ALL_PROXY`.
- `System Proxy`: CLI calls use the current macOS HTTP/HTTPS proxy settings.

The selected mode is saved with macOS user defaults. First launch defaults to `Direct`; if you switch to `System Proxy`, that choice remains after quitting and reopening the app.

## Third Party Accounts

`Add New Account` lets you choose between:

- `Codex Account`: opens the existing `codex-auth login` flow in Terminal.
- `Third Party Account`: opens a local form for a third-party Codex provider.

Third Party accounts require:

- `API Remark`: your local display name for this API key.
- `Codex Provider Name`: the provider label shown next to `Current Account`, for example `DeepSeek`, `GLM`, or a custom provider name.
- `API Key`
- `API Request URL`
- `Endpoint Type`: `Base URL` or `Full URL`
- `Model Name`

`Official Website` is optional.

Multiple Third Party accounts can be saved. Non-sensitive provider metadata is stored in:

```text
~/Library/Application Support/CodexAuthMenu/third-party-accounts.json
```

API Keys are not written to that file. Each account uses its own UUID-backed macOS Keychain item under the `CodexAuthMenu.ThirdPartyAPIKey` service, so adding or editing one provider does not overwrite another provider's Key.

When a Third Party account is active, the menu bar displays `API`, the main menu hides the `5H` and `W` quota lines, and the account list shows `Third Party`. `Query Interval` still refreshes `codex-auth` account usage in the background, but this app does not query Third Party balance or quota.

### Codex Config Writes

Switching to a Third Party account updates the user-level Codex files:

```text
~/.codex/config.toml
~/.codex/auth.json
```

The app writes a unique `model_provider`, `model`, and `[model_providers.<id>]` block for the selected provider. It also temporarily writes an API-key `auth.json` containing `OPENAI_API_KEY`, so Codex identifies the session as API Key mode instead of continuing to display the ChatGPT account.

Before the first Third Party switch, the existing official `auth.json` is backed up under:

```text
~/Library/Application Support/CodexAuthMenu/official-auth.json.backup
```

Switching back to a Codex account restores that exact official `auth.json`. Provider-related `config.toml` fields are restored separately, leaving unrelated Codex config such as MCP, sandbox, permissions, and profiles intact.

Existing Codex sessions may have already loaded the old config. Restart Codex sessions after switching providers.

### Base URL vs Full URL

- `Base URL`: a provider root such as `https://api.example.com/v1`. Codex will use it as the Responses API base.
- `Full URL`: a complete Responses endpoint. For direct Codex use, it must end with `/responses` or `/v1/responses`; the app derives the base URL before writing `config.toml`.

The first Third Party release only supports providers compatible with the OpenAI Responses API. Chat Completions-only providers such as DeepSeek/Kimi-style `/chat/completions` endpoints can be saved for later, but enabling them is blocked until local routing and protocol conversion are implemented.

## Known Issues

- `codex-auth` is required. If the app opens but cannot show accounts or usage, first run `codex-auth status` and `codex-auth list` in Terminal.
- When `Proxy Mode` is set to `System Proxy`, using Whistle to capture HTTPS traffic can cause the underlying `codex-auth` Node.js request to the OpenAI/ChatGPT usage API to return `RequestFailed`. This is commonly caused by Node.js not trusting Whistle's HTTPS interception certificate. Use `Direct` mode for normal app usage, or configure Node.js to trust your Whistle CA certificate yourself.
- Third Party API keys are stored in macOS Keychain. While a Third Party account is active, its key is also projected into `~/.codex/auth.json` because Codex uses that file to select API Key authentication mode.

## Notes

- This app shells out to the upstream `codex-auth` CLI for all account, switching, and usage operations.
- Rebuild the app after changing files under `Sources/` or resources used by `build-app.sh`.
