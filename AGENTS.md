# events - AGENTS.md

## Project Overview
A Swift CLI tool that wraps Apple's EventKit framework, enabling AI agents to interact with the user's Calendar and Reminders via structured JSON output. All commands output JSON to stdout with typed exit codes.

## Tech Stack
- **Language**: Swift 6
- **IDE**: Xcode
- **Platforms**: macOS
- **Minimum Deployment**: macOS 14.0

## Style & Conventions (MANDATORY)
**Strictly follow** the Swift/SwiftUI style guide: `~/Agents/Style/swift-swiftui-style-guide.md`

## Changelog (MANDATORY)
**All important code changes** (fixes, additions, deletions, changes) have to written to CHANGELOG.md.
Changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Before writing to CHANGELOG.md:**
1. Check for new release tags: `git tag --sort=-creatordate | head -1`
2. Release tags are prefixed with `v` (e.g., `v2.0.1`)
3. If a new tag exists that isn't in CHANGELOG.md, create a new version section with that tag's version and date, moving relevant [Unreleased] content under it

## Additional Guides
- Swift 6 concurrency: `~/Agents/Guides/swift6-concurrency-guide.md`
- Swift 6 migration (compact): `~/Agents/Guides/swift6-migration-compact-guide.md`
- Swift 6 migration (full): `~/Agents/Guides/swift6-migration-full-guide.md`

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

## API Documentation
Local Apple API documentation is available at:
`~/Agents/API Documentation/Apple/`

The `search` binary is located **inside** the documentation folder:
```bash
~/Agents/API\ Documentation/Apple/search --help  # Run once per session
~/Agents/API\ Documentation/Apple/search "view controller" --language swift
~/Agents/API\ Documentation/Apple/search "NSWindow" --type Class
```

## Xcode Project Files (CATASTROPHIC — DO NOT TOUCH)
- **NEVER edit Xcode project files** (`.xcodeproj`, `.xcworkspace`, `project.pbxproj`, `.xcsettings`, etc.)
- Editing these files will corrupt the project — this is **catastrophic and unrecoverable**
- Only the user edits project settings, build phases, schemes, and file references manually in Xcode
- If a file needs to be added to the project, **stop and tell the user** — do not attempt it yourself
- Use `xcodebuild` for building/testing only — never for project manipulation
- **Exception**: Only proceed if the user gives explicit permission for a specific edit
  
## File System Synchronized Groups (Xcode 16+)
This project uses **File System Synchronized Groups** (internally `PBXFileSystemSynchronizedRootGroup`), introduced in Xcode 16. This means:
- The `Classes/` and `Resources/` directories are **directly synchronized** with the file system
- **You CAN freely create, move, rename, and delete files** in these directories
- Xcode automatically picks up all changes — no project file updates needed
- This is different from legacy Xcode groups, which required manual project file edits

**Bottom line:** Modify source files in `Classes/` and `Resources/` freely. Just never touch the `.xcodeproj` files themselves.

## Build & Format Commands
```bash
# Build
xcodebuild -scheme "events" -destination "platform=macOS" build

# Run tests
xcodebuild -scheme "events" -destination "platform=macOS" test

# Clean
xcodebuild -scheme "events" clean
```

## Code Formatting (MANDATORY)
**Always run SwiftFormat after a successful build:**
```bash
swiftformat .
```

SwiftFormat configuration is defined in `.swiftformat` at the project root. This enforces:
- 4-space indentation
- Explicit `self.` usage
- K&R brace style
- Trailing commas in collections
- Consistent wrapping rules

**Do not commit unformatted code.**

---

## Help Output / Status Command (MANDATORY)
The `events status` command is the **single source of truth** for AI agents. It documents every command, every parameter, and every output field.

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
- Always run `swiftformat .` after successful builds before committing