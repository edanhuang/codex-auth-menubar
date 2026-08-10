# Moon Bridge Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically install, launch, verify, and stop a private Moon Bridge as DeepSeek accounts are selected or left.

**Architecture:** Keep Codex file mutation in `CACodexConfigManager`. Add `CAMoonBridgeManager` to `Sources/main.m` for installation, private config creation, HTTP health checks, owned-process state, and shutdown. `AppDelegate` orchestrates it before and after account configuration transactions.

**Tech Stack:** Objective-C ARC, AppKit/Foundation, `NSTask`, macOS Keychain, Git, Go, Moon Bridge.

## Global Constraints

- Install only under `~/Library/Application Support/CodexAuthMenu/moon-bridge`.
- Clone `https://github.com/ZhiYi-R/moon-bridge.git`; build `./cmd/moonbridge` with the local `go` command.
- Read DeepSeek keys only from existing Keychain records; never log them or store them in process state.
- Generate `config.yml` with `0600` permissions and delete it after a managed process is stopped.
- Reuse but never stop or reconfigure external Moon Bridge processes.
- Bind only the selected account's loopback `/v1` endpoint and default its upstream model to `deepseek-v4-flash`.

---

### Task 1: Model DeepSeek routes and generate Moon Bridge configuration

**Files:**
- Modify: `Sources/main.m` near URL helpers and `CAThirdPartyAccount`
- Test: `Sources/main.m` in `CARunConfigRoundTripVerification`

**Interfaces:**
- Produces `-isDeepSeekProvider`, `CAEndpointIsLocalResponsesProxy`, and `CAMoonBridgeConfigurationForAccount(account, apiKey, error)`.

- [x] **Step 1: Write failing verification cases** for a DeepSeek loopback account. Assert that the generated YAML contains `addr: "127.0.0.1:38440"`, `base_url: "https://api.deepseek.com/anthropic"`, and `deepseek-v4-flash`; assert a non-loopback DeepSeek URL is rejected.
- [x] **Step 2: Run `./CodexAuthMenu.app/Contents/MacOS/CodexAuthMenu --verify-config-roundtrip`** and confirm the new case fails before implementation.
- [x] **Step 3: Implement parsed loopback endpoint validation and YAML generation** without writing the key to diagnostic output.
- [x] **Step 4: Rebuild and rerun verification**; expect `Config roundtrip verification passed.`

### Task 2: Add private installation and owned-process lifecycle manager

**Files:**
- Modify: `Sources/main.m` after `CACodexConfigManager`
- Test: `Sources/main.m` in `CARunConfigRoundTripVerification`

**Interfaces:**
- Produces `CAMoonBridgeManager` with `ensureRunningForAccount:apiKey:error:`, `stopManagedBridgeIfOwned:error:`, and `isExternallyOwned`.

- [x] **Step 1: Add a failing verification case** that launches a temporary owned `sleep` process through the manager's stop primitive and asserts it no longer exists after stop.
- [x] **Step 2: Run the verifier** and confirm the process-stop assertion fails before the stop primitive exists.
- [x] **Step 3: Implement install checks, private directory/file helpers, source clone, Go build, YAML write, `NSTask` launch, PID state validation, HTTP `/v1/models` health polling, graceful shutdown, and external-process detection.**
- [x] **Step 4: Rebuild and rerun verification**; expect all configuration and owned-process checks to pass.

### Task 3: Make account transitions transactional around Moon Bridge

**Files:**
- Modify: `Sources/main.m` in `AppDelegate` switch, delete, launch, and terminate paths
- Test: `Sources/main.m` verification mode for DeepSeek configuration selection

**Interfaces:**
- Consumes `CAMoonBridgeManager` and `CAThirdPartyAccount -isDeepSeekProvider`.
- Produces safe DeepSeek-to-Codex, Codex-to-DeepSeek, DeepSeek-to-DeepSeek, delete-active, app-launch, and app-quit behavior.

- [x] **Step 1: Extend verification fixtures** to exercise DeepSeek configuration selection and ensure legacy `openai_chat` account metadata remains accepted only through a local bridge endpoint.
- [x] **Step 2: Run verifier and observe failure before orchestration implementation.**
- [x] **Step 3: Ensure DeepSeek before Codex writes; stop a newly-started bridge on write failure; stop owned bridge before leaving DeepSeek; asynchronously ensure the persisted DeepSeek account at app launch; call stop from `applicationWillTerminate:`.**
- [x] **Step 4: Rebuild and rerun verification**; expect no failures.

### Task 4: Document and deliver

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-08-10-moon-bridge-lifecycle-design.md`

- [x] **Step 1: Document automatic first-use installation, Go/Git prerequisites, private install location, account fields, external bridge behavior, and shutdown rules.**
- [x] **Step 2: Run `./build-app.sh && ./CodexAuthMenu.app/Contents/MacOS/CodexAuthMenu --verify-config-roundtrip && git diff --check`.**
- [x] **Step 3: Inspect `git status --short`** and report only the intended source, documentation, and generated-app changes.
