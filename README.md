# CodexAuthMenu

Minimal macOS menu bar app for `codex-auth`.

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

## Assumptions

- `codex-auth` lives at `/usr/local/bin/codex-auth`
- macOS 13+
- Xcode Command Line Tools with `clang`
