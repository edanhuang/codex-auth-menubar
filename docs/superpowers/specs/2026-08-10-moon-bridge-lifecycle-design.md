# Moon Bridge Lifecycle Design

## Goal

When the selected third-party account is DeepSeek, CodexAuthMenu automatically installs, configures, starts, verifies, and owns a local Moon Bridge. When the user leaves a DeepSeek account or quits the menu-bar app, it stops only the Moon Bridge process it owns.

## Boundaries

- The installation is private to `~/Library/Application Support/CodexAuthMenu/moon-bridge`.
- The app clones the official `https://github.com/ZhiYi-R/moon-bridge.git` source and builds `./cmd/moonbridge` with the locally installed `go` command. It does not use Homebrew or change the user's PATH.
- The selected DeepSeek account's API key is read from the existing Keychain entry and used to generate Moon Bridge's private `config.yml`. The configuration uses `deepseek-v4-flash` and DeepSeek's Anthropic endpoint.
- The generated configuration and process-state file use private permissions. The configuration is deleted after a managed process exits.
- A locally running, healthy Moon Bridge that was not started by CodexAuthMenu is reused and never terminated or reconfigured.
- A DeepSeek account must target a loopback Responses endpoint (`http://127.0.0.1:<port>/v1`, `http://localhost:<port>/v1`, or IPv6 loopback equivalent). The endpoint's host and port become Moon Bridge's listen address.

## Components

`CAThirdPartyAccount` gains DeepSeek and local-router predicates. `CACodexConfigManager` remains responsible only for Codex files. A new `CAMoonBridgeManager` owns all Moon Bridge responsibilities:

1. Validate the selected account and derive the local listener address.
2. Check `<base-url>/models`; a healthy pre-existing endpoint is reported as externally owned.
3. Clone the official source on first use, then build the local binary if it is missing.
4. Generate a `0600` YAML configuration from the active account key.
5. Launch the binary with `NSTask`, persist an owner-state record containing the PID and canonical executable path, and wait for `/v1/models` to become healthy.
6. Stop only a recorded PID whose current command still contains the expected executable path. It sends `SIGTERM`, waits briefly, then sends `SIGKILL` only if needed. It deletes state and generated config in either terminal outcome.

## Switching Flow

### Switching to DeepSeek

The app obtains the API key from Keychain and calls `ensureRunningForAccount`. A newly started service is health-checked before any Codex auth/config write occurs. If a later Codex write fails, the newly started managed process is stopped so the previous configuration remains usable. Once all writes succeed, the account is persisted as active.

When moving between two DeepSeek accounts, the app stops its currently managed bridge, starts a bridge using the destination account configuration, and restores the previous bridge configuration if the destination fails before Codex is switched. An external bridge is never stopped or reconfigured.

### Leaving DeepSeek

When switching to a Codex account, another non-DeepSeek provider, deleting the active DeepSeek account, or terminating the app, the app first calls `stopManagedBridgeIfOwned`. It then restores the official Codex configuration or continues the requested account switch. A stop failure prevents the switch and reports the error, avoiding an ambiguous state.

At app launch, if the persisted active account is DeepSeek, the app ensures a healthy Moon Bridge asynchronously. This recovers the intended selected account after a normal app quit, which had stopped its managed bridge.

## Error Handling

- Missing `git` or `go`, clone failures, build failures, invalid loopback URL, process launch failures, and health-check timeouts surface a specific error and do not modify Codex configuration.
- Existing healthy loopback bridge: use it as external ownership and leave it untouched on all stop paths.
- Occupied but unhealthy port: fail rather than killing an unknown process.
- The Keychain key is never logged or stored in the process-state record.

## Verification

The executable's built-in verification mode covers the existing Codex configuration round trip, DeepSeek Moon Bridge configuration generation, local endpoint parsing, and owned-process stop behavior using a temporary local process. A production build plus the verification mode must pass before delivery.
