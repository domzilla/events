# events - AGENTS.md

## Project Overview
A Swift CLI tool that wraps Apple's EventKit framework, enabling AI agents to interact with the user's Calendar and Reminders via structured JSON output. All commands output JSON to stdout with typed exit codes.

## Tech Stack
- **Language**: Swift
- **IDE**: Xcode
- **Platforms**: macOS
- **Dependencies**: none beyond system frameworks (EventKit, Foundation)

## Guides (MANDATORY)
Read `~/Agents/Guides/xcode-project-guide.md` in full before planning or editing anything.

Read these in full before touching the matching code:
- Swift style (`.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`

## Logging (MANDATORY)
This project uses a built-in `Logger` enum (`src/events/Classes/Logger.swift`) that writes to **stderr**. This is a deliberate exception to the shared logging rule: stdout is reserved for JSON output.

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
xcodebuild -project src/events.xcodeproj -scheme "events" -destination "platform=macOS" build

# Clean
xcodebuild -project src/events.xcodeproj -scheme "events" clean
```

## Testing (MANDATORY)
No test targets exist in this project.

## Help Output (MANDATORY)
The help system is the **single source of truth** for AI agents. `events -h` lists all commands, `<command> -h` shows full parameter and output documentation.

**Rules:**
- Every command and flag **must** be documented in the `commandList()` method in `CLI.swift`
- Every output field **must** be documented in the output schema of the corresponding command
- A command or flag that is not in the help output **does not exist** for the agent
- When adding/changing/removing commands, flags, or output fields: **always update `commandList()` in the same commit**
- The help output must stay in sync with the actual implementation at all times

## Notes
- This is a CLI tool — no SwiftUI, no UI framework dependencies
- Use `async/await` for async work (EventKit callback APIs wrapped with `withCheckedContinuation`)
- `@MainActor` on all service classes to isolate the non-Sendable `EKEventStore`
