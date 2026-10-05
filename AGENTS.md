# events - AGENTS.md

## Project Overview
A Swift CLI tool that wraps Apple's EventKit framework, enabling AI agents to interact with the user's Calendar and Reminders via structured JSON output. All commands output JSON to stdout with typed exit codes.

## Tech Stack
- **Language**: Swift
- **IDE**: Xcode
- **Platforms**: macOS

## Guides (MANDATORY)
Read `~/Agents/Guides/xcode-project-guide.md` in full before planning or editing anything.

Read these in full before touching the matching code:
- Swift style (`.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`
- Accessibility (UI code, XIBs, storyboards): `~/Agents/Guides/accessibility-guide.md`

## Logging (MANDATORY)
This project uses a built-in `Logger` enum (`Classes/Logger.swift`) that writes to **stderr**.

**All debug logging must use:**
- `Logger.debug("message")` — General debug output (writes to stderr)
- `Logger.error(error)` — Conditional error logging (only logs if error is non-nil)

```swift
Logger.debug("Starting fetch")   // [DEBUG] fetchData():42 Starting fetch
Logger.error(error)               // [ERROR] fetchData():45 Network unavailable
```

**Do NOT use:**
- `print()` for debug output — stdout is reserved for JSON output
- `os.Logger` instances
- `NSLog`
- `DZFoundation` / `DZLog`

Both functions are no-ops in release builds.

## Build Commands
```bash
# Build
xcodebuild -scheme "events" -destination "platform=macOS" build

# Clean
xcodebuild -scheme "events" clean
```

## Testing (MANDATORY)
No test targets exist in this project.

## Help Output / Status Command (MANDATORY)
The help system is the **single source of truth** for AI agents. `events -h` lists all commands, `<command> -h` shows full parameter and output documentation.

**Rules:**
- Every command and flag **must** be documented in the `commandList()` method in `CLI.swift`
- Every output field **must** be documented in the output schema of the corresponding command
- A command or flag that is not in the status output **does not exist** for the agent
- When adding/changing/removing commands, flags, or output fields: **always update `commandList()` in the same commit**
- The status output must stay in sync with the actual implementation at all times

## Notes
- This is a CLI tool — no SwiftUI, no UI framework dependencies
- Use `async/await` for async work (EventKit callback APIs wrapped with `withCheckedContinuation`)
- `@MainActor` on all service classes to satisfy Swift 6 Sendable requirements with non-Sendable EKEventStore
- Use `Logger.debug`/`Logger.error` for debug logging — never `print()` (stdout is JSON output)
