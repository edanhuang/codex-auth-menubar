# Shared `custom` Provider Design

## Goal

Keep Codex conversation history in one model-provider group while switching between the official account and any saved third-party API account.

## Behavior

- Every third-party activation writes `model_provider = "custom"` and updates only the `custom` provider's model, API base URL, display name, and API-key authentication mode.
- DeepSeek continues to route through Moon Bridge, but its generated local route is also written under `model_providers.custom`.
- Switching from one third-party account to another keeps the same `custom` provider identifier and changes only its runtime settings.
- Switching back to an official Codex account restores the exact pre-third-party top-level model settings and the original `[model_providers.custom]` block.

## Configuration Safety

The existing implementation snapshots only top-level keys. This change extends the first-third-party snapshot to include the full `model_providers.custom` section, including its original OpenAI fields. Before applying a third-party configuration, the app removes the currently active `custom` block to prevent duplicate TOML tables. Restore then replaces it from the snapshot. Other provider blocks, MCP settings, project settings, and unrelated configuration remain unchanged.

## Verification

The built-in round-trip verification will prove that applying a third-party account uses `model_provider = "custom"`, produces one `model_providers.custom` block, and that restore reproduces the original custom block while preserving unrelated configuration.
