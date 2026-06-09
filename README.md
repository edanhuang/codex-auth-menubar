# CodexAuthMenu

Minimal macOS menu bar app for `codex-auth`.

This repository does not include or reimplement the upstream CLI. It only provides a lightweight macOS menu bar wrapper around:

- Upstream CLI: [Loongphy/codex-auth](https://github.com/Loongphy/codex-auth)
- This app: a local macOS menu bar UI that shells out to `codex-auth`

## Features

- Poll `codex-auth status` and `codex-auth list` on launch and then every `1/5/10/20/30/60` minutes
- Show active account, 5h usage, weekly usage, and service status
- Confirm before switching accounts from the menu bar
- Enable or disable auto-switching
- Send a macOS notification when 5h or weekly usage reaches 90%+
- Open the raw CLI status in Terminal
- Choose whether CLI calls use `Direct` networking or the macOS `System Proxy`

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

## Known Issues

- `codex-auth` is required. If the app opens but cannot show accounts or usage, first run `codex-auth status` and `codex-auth list` in Terminal.
- When `Proxy Mode` is set to `System Proxy`, using Whistle to capture HTTPS traffic can cause the underlying `codex-auth` Node.js request to the OpenAI/ChatGPT usage API to return `RequestFailed`. This is commonly caused by Node.js not trusting Whistle's HTTPS interception certificate. Use `Direct` mode for normal app usage, or configure Node.js to trust your Whistle CA certificate yourself.

## Notes

- This app shells out to the upstream `codex-auth` CLI for all account, switching, and usage operations.
- Rebuild the app after changing files under `Sources/` or resources used by `build-app.sh`.
