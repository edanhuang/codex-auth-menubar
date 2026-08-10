# Shared `custom` Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep all official and third-party Codex sessions in the `custom` model-provider group while preserving and restoring the user's original OpenAI `custom` configuration.

**Architecture:** `CACodexConfigManager` will treat `custom` as the sole managed third-party provider ID. Its first-third-party snapshot will retain both the relevant top-level fields and the original full `[model_providers.custom]` section. Applying a third-party account removes the current custom section and writes one replacement; restoring removes the replacement and reinstates the snapshot section.

**Tech Stack:** macOS Objective-C, Foundation/AppKit, TOML text transformation, built-in `--verify-config-roundtrip` regression check.

## Global Constraints

- Third-party account metadata and Keychain identifiers remain account-specific; only the Codex `model_provider` value is shared as `custom`.
- DeepSeek must retain its Moon Bridge lifecycle and must write the local Moon Bridge route under `model_providers.custom`.
- The restore path must preserve unrelated provider sections, MCP settings, project settings, and existing top-level configuration not managed by this app.
- Do not stage, commit, or push changes.

---

### Task 1: Snapshot and restore the original `custom` provider section

**Files:**
- Modify: `Sources/main.m:622-1010`
- Test: `Sources/main.m:3330-3435` (`CARunConfigRoundTripVerification`)

**Interfaces:**
- Consumes: `+snapshotFromConfigText:` and `+configTextByRestoringSnapshot:removingProviderIDs:fromText:`.
- Produces: snapshots with a `providerSections.custom` dictionary containing `present` (`BOOL`) and `text` (`NSString`), and restore output with the original custom section reinstated exactly once.

- [ ] **Step 1: Write the failing round-trip verification**

Extend `original` in `CARunConfigRoundTripVerification` with an official custom section and assert its exact settings are present after restore:

```objective-c
NSString *original = @"model_provider = \"custom\"\n"
                     "model = \"gpt-5.6-terra\"\n"
                     "\n"
                     "[model_providers.custom]\n"
                     "name = \"OpenAI\"\n"
                     "requires_openai_auth = true\n"
                     "wire_api = \"responses\"\n";
// ... apply third-party config, then restore snapshot ...
if (![restored containsString:@"[model_providers.custom]\\nname = \"OpenAI\""] ||
    ![restored containsString:@"requires_openai_auth = true"]) {
    fprintf(stderr, "Original custom provider was not restored.\\n");
    return 1;
}
```

- [ ] **Step 2: Run the verification to confirm it fails**

Run:

```zsh
./build-app.sh
env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin ./CodexAuthMenu.app/Contents/MacOS/CodexAuthMenu --verify-config-roundtrip
```

Expected: failure because the current snapshot excludes `[model_providers.custom]` and the restore path does not reinsert it.

- [ ] **Step 3: Add section snapshot helpers and restoration**

Add a helper that captures a complete TOML provider section, stopping at the next section header. Extend `snapshotFromConfigText:` with a `providerSections` dictionary. During restore, remove `custom` with the managed IDs, then append the stored `providerSections.custom.text` only when its `present` value is true:

```objective-c
NSDictionary *customSection = [self providerSectionSnapshotForProviderID:@"custom" inText:text];
return @{
    @"topLevel": topLevel,
    @"providerSections": @{ @"custom": customSection },
    @"createdAt": @([[NSDate date] timeIntervalSince1970])
};
```

- [ ] **Step 4: Run the verification to confirm the restore passes**

Run the command from Step 2.

Expected: `Config roundtrip verification passed.`

### Task 2: Write every third-party route through the shared `custom` ID

**Files:**
- Modify: `Sources/main.m:20-35`, `Sources/main.m:940-1005`, `Sources/main.m:3330-3435`
- Test: `Sources/main.m:3330-3435` (`CARunConfigRoundTripVerification`)

**Interfaces:**
- Consumes: `CACodexSharedProviderID` (`@"custom"`) and the snapshot/restore behavior from Task 1.
- Produces: `configTextByApplyingThirdPartyAccount:apiKey:toText:error:` output with `model_provider = "custom"` and exactly one `[model_providers.custom]` block for regular and Moon Bridge-routed accounts.

- [ ] **Step 1: Change the existing apply assertions so they fail under per-account IDs**

Replace the provider-ID assertions in the existing verifier with shared-ID assertions:

```objective-c
if (![applied containsString:@"model_provider = \"custom\""] ||
    ![applied containsString:@"[model_providers.custom]"] ||
    [applied containsString:@"[model_providers.codex_auth_menu_verify]"]) {
    fprintf(stderr, "Third Party config did not use the shared custom provider.\\n");
    return 1;
}
```

Also assert the DeepSeek Moon Bridge configuration contains `model_provider = "custom"` and `[model_providers.custom]`.

- [ ] **Step 2: Run the verification to confirm it fails**

Run the command from Task 1, Step 2.

Expected: failure because the current apply path uses `account.codexProviderID`.

- [ ] **Step 3: Implement the shared provider constant and minimal replacement**

Declare a single constant near the existing config constants:

```objective-c
static NSString *const CACodexSharedProviderID = @"custom";
```

In `configTextByApplyingThirdPartyAccount:apiKey:toText:error:`, remove both the account's legacy ID and `CACodexSharedProviderID`, then use `CACodexSharedProviderID` in the top-level `model_provider` setting and the generated provider section header. Keep model, base URL, provider name, and Responses API behavior unchanged.

- [ ] **Step 4: Run the verification to confirm shared routing and restore both pass**

Run:

```zsh
./build-app.sh
env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin ./CodexAuthMenu.app/Contents/MacOS/CodexAuthMenu --verify-config-roundtrip
git diff --check
```

Expected: application build succeeds, verifier prints `Config roundtrip verification passed.`, and `git diff --check` reports no whitespace errors.

### Task 3: Document the shared session grouping

**Files:**
- Modify: `README.md:134-153`

**Interfaces:**
- Consumes: the fixed `custom` provider behavior from Task 2.
- Produces: documentation that distinguishes per-account stored metadata from the single Codex session provider group.

- [ ] **Step 1: Update the third-party config documentation**

Replace the claim that every account writes a unique `model_provider` with:

```markdown
All Third Party accounts use the fixed Codex provider ID `custom`. Switching accounts updates that shared route and keeps Codex conversation history in one provider group. The original `custom` configuration is snapshotted before the first Third Party switch and restored when returning to an official account.
```

- [ ] **Step 2: Run final build and verification**

Run the command from Task 2, Step 4.

Expected: the app builds and all built-in configuration checks pass.
