# CodexAuthMenu

Minimal macOS menu bar app for `codex-auth`.

This repository does not reimplement the CLI itself. It adds a lightweight macOS menu bar app on top of the upstream `codex-auth` project:

- Upstream CLI: [Loongphy/codex-auth](https://github.com/Loongphy/codex-auth)
- This repo: menu bar wrapper for that CLI on macOS

## Features

- Poll `codex-auth status` and `codex-auth list` on launch and then every `1/5/10/20/30/60` minutes
- Show active account, 5h usage, weekly usage, and service status
- Confirm before switching accounts from the menu bar
- Enable or disable auto-switching
- Send a macOS notification when 5h or weekly usage reaches 90%+
- Open the raw CLI status in Terminal

## Build

```bash
./build-app.sh
open ./CodexAuthMenu.app
```

## Requirements

- Node.js 22
- `codex-auth` lives at `/usr/local/bin/codex-auth`
- macOS 13+
- Xcode Command Line Tools with `clang`

## Before Use: Install Upstream CLI

```bash
npm install -g @loongphy/codex-auth
```

## Notes

- This app shells out to the upstream `codex-auth` CLI for all account and usage operations.
- If `codex-auth` is not installed or not working, this menu app will not function correctly.
