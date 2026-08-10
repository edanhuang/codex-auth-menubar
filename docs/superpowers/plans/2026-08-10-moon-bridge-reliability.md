# Moon Bridge Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DeepSeek edit, leave, and delete transitions rollback-safe and prevent Moon Bridge installation commands from blocking on output pipes.

**Architecture:** `CAMoonBridgeManager` remains the owner of Bridge processes. AppDelegate retains the previous active DeepSeek account/key and uses a shared rollback helper whenever downstream configuration or persistence fails. `CACommandOutput` redirects both child streams to a private temporary log, then returns a bounded diagnostic after exit.

**Tech Stack:** macOS Objective-C, Foundation/AppKit, `NSTask`, Keychain Services, built-in `--verify-config-roundtrip` verification.

## Global Constraints

- Stop only Bridge processes recorded as owned by this app; never terminate an external local listener.
- A failed DeepSeek transition must restore the prior usable route when the old account/key is available.
- Child stdout and stderr must not remain unread while a task runs.
- Temporary diagnostics must be private and removed after collection.
- Do not stage, commit, or push during implementation.

---

### Task 1: Capture command output without pipe deadlock

**Files:**
- Modify: `Sources/main.m:1022-1058`
- Test: `Sources/main.m:3345-3510` (`CARunConfigRoundTripVerification`)

**Interfaces:**
- Consumes: `CACommandOutput(NSString *, NSArray<NSString *> *, NSString *, NSError **)`.
- Produces: identical success/error semantics using a temporary log and no unread child-output pipe.

- [ ] **Step 1: Write the failing verbose-output verification**

Add a verifier that runs a shell command emitting more than 64 KiB and requires `CACommandOutput` to return:

```objective-c
NSError *verboseError = nil;
NSString *verboseOutput = CACommandOutput(@"/bin/sh",
    @[ @"-c", @"i=0; while [ $i -lt 20000 ]; do echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx; i=$((i+1)); done" ],
    nil,
    &verboseError);
if (!verboseOutput || verboseError) {
    fprintf(stderr, "Verbose command output verification failed.\n");
    return 1;
}
```

- [ ] **Step 2: Run the verifier to observe the pre-fix unsafe behavior**

Run:

```zsh
./build-app.sh
env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin ./CodexAuthMenu.app/Contents/MacOS/CodexAuthMenu --verify-config-roundtrip
```

Expected: the existing wait-before-drain order cannot safely handle high output.

- [ ] **Step 3: Replace pipes with one private temporary log**

Create a unique `0600` file under `NSTemporaryDirectory()`; assign its writable handle to both streams; wait for exit; read at most the last 8 KiB for a nonzero-exit diagnostic; close and delete the log in every exit path:

```objective-c
task.standardOutput = logHandle;
task.standardError = logHandle;
[task launch];
[task waitUntilExit];
NSData *outputData = [NSData dataWithContentsOfFile:logPath];
[[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
```

- [ ] **Step 4: Re-run the verifier**

Run the command from Step 2.

Expected: `Config roundtrip verification passed.`

### Task 2: Roll back a failed DeepSeek departure

**Files:**
- Modify: `Sources/main.m:2022-2065`, `Sources/main.m:2276-2315`
- Test: `Sources/main.m:3345-3510`

**Interfaces:**
- Consumes: `CAMoonBridgeManager ensureRunningForAccount:apiKey:error:` and `stopManagedBridgeIfOwned:`.
- Produces: `-restorePreviousDeepSeekBridgeForAccount:apiKey:originalError:`, which preserves the original failure and adds rollback detail only if restart fails.

- [ ] **Step 1: Write failing rollback coverage**

Introduce a test seam that records a retained DeepSeek account/key and simulates a failure after the owned Bridge is stopped:

```objective-c
if (!rollbackWasAttempted) {
    fprintf(stderr, "DeepSeek departure rollback was not attempted.\n");
    return 1;
}
```

- [ ] **Step 2: Run the verifier to confirm the missing rollback**

Run the command from Task 1, Step 2.

Expected: failure because current official-switch and delete flows do not restart the prior Bridge.

- [ ] **Step 3: Implement retained-key rollback**

Read the active DeepSeek key before stopping its Bridge in `switchAccount:` and `deleteThirdPartyAccount:error:`. On any later restore, account-save, or Keychain-delete failure, call the rollback helper. Defer clearing active ID and permanent account/key deletion until all departure work succeeds.

- [ ] **Step 4: Re-run the verifier**

Run the command from Task 1, Step 2.

Expected: `Config roundtrip verification passed.`

### Task 3: Transactionally reconfigure an active DeepSeek edit

**Files:**
- Modify: `Sources/main.m:2318-2340`, `Sources/main.m:2518-2560`
- Test: `Sources/main.m:3345-3510`

**Interfaces:**
- Consumes: original and edited `CAThirdPartyAccount` values, their keys, `CAMoonBridgeManager`, and `rewriteConfigForActiveThirdPartyAccount:error:`.
- Produces: active DeepSeek saves that reconfigure the managed Bridge before persistence and recover the old route on failure.

- [ ] **Step 1: Write a failing active-edit transaction verifier**

Use original and edited DeepSeek fixtures with distinct listener ports and assert the edited fixture is started before config write and the old fixture is restarted after a forced write failure:

```objective-c
if (bridgeStartAccount != editedAccount || !oldBridgeRestartedAfterForcedFailure) {
    fprintf(stderr, "Active DeepSeek edit did not reconfigure and roll back Moon Bridge.\n");
    return 1;
}
```

- [ ] **Step 2: Run the verifier to confirm it fails**

Run the command from Task 1, Step 2.

Expected: failure because current active-edit flow only rewrites Codex configuration.

- [ ] **Step 3: Implement the edit transaction**

Retain original account/key, stop its app-owned Bridge, ensure the edited Bridge is healthy, rewrite Codex config, then persist account metadata and new Keychain value. On failure, stop any newly started Bridge, restore stored account/key state, reapply the old active config when needed, and restart the original Bridge.

- [ ] **Step 4: Run final verification**

Run:

```zsh
./build-app.sh
env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin ./CodexAuthMenu.app/Contents/MacOS/CodexAuthMenu --verify-config-roundtrip
git diff --check
```

Expected: application build succeeds, verifier prints `Config roundtrip verification passed.`, and no whitespace errors are reported.
