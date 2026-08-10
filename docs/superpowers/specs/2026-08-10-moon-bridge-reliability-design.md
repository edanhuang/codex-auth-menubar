# Moon Bridge Reliability Design

## Goal

Make DeepSeek account edits and departures recoverable, and prevent first-use installation commands from leaving the menu bar app permanently in a switching state.

## DeepSeek Edit Transaction

Editing an active DeepSeek account is a transaction. The app retains the old account metadata and API key until the new Bridge is healthy and Codex configuration is written. It then stops the app-owned old Bridge, starts and health-checks a Bridge using the edited account, rewrites Codex configuration, and persists the account change. If any operation after stopping the old Bridge fails, the app stops the attempted new Bridge, restores the old account/key metadata, re-applies the old Codex route when needed, and restarts the old Bridge.

## Leave/Delete Rollback

When switching from DeepSeek to an official account or deleting the active DeepSeek account, the app reads the current API key before stopping its managed Bridge. If restoring official Codex configuration, saving the reduced account list, or deleting the Keychain item fails, it restores the active DeepSeek state by restarting the previous Bridge. Account metadata and Keychain deletion only become permanent after the route restoration succeeds.

## Bounded Command Output

Moon Bridge installation commands write stdout and stderr to one private temporary log instead of pipes. The app waits for process completion without a pipe back-pressure deadlock, reads only a bounded trailing diagnostic on failure, then deletes the log. The UI reports that Moon Bridge is being installed or built during this work.

## Verification

The built-in verifier covers command-output draining and configuration behavior. Transaction helpers are factored to make active-DeepSeek edit and leave-failure rollback testable with controlled Bridge state; the manual acceptance path verifies a changed API key or local listener is immediately reflected in a healthy managed Bridge.
