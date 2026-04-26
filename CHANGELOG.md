# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `events config init` generates a default configuration file at `~/.config/events/config`.
- Configuration support for `default_calendar`, `default_duration`, and `default_alarm`.

### Changed
- The `--calendar`, `--end`, and `--alarm` flags on `events create` are now optional and fall back to their configured defaults.

## [1.0.1] - 2026-03-26

### Changed
- Bumped GitHub Actions to v5 for Node.js 24 compatibility.

## [1.0.0] - 2026-03-26

### Added
- Initial release of `events`, a Swift CLI that wraps EventKit and outputs structured JSON.
- Calendar event commands: `list`, `search`, `get`, `create`, `update`, `delete`.
- Reminder commands: `reminders list`, `search`, `get`, `create`, `update`, `delete`, `complete`.
- `events status` reports authorization state, and `events calendars list` enumerates available calendars.
- Recurrence support on `events create` (`--recurrence`, `--recurrence-interval`, `--recurrence-end`, `--recurrence-count`).
- `--occurrence-date` flag on `get`, `update`, and `delete` to target a single occurrence of a recurring event.
- `--alarm <minutes>` flag on `events update` and `events reminders update`.
- `--span this|future` for updating and deleting recurring events.
- Hierarchical help system: `events -h` and `<command> -h` show usage, parameters, and output schema.
- `--version` / `-v` flag.
- Date parsing accepts local datetimes without timezone, and output now includes the timezone offset and IANA `timeZone` field.
- Homebrew tap publishing via GitHub Actions, plus a `.publish` configuration and an MIT license.

### Changed
- Help output now uses human-readable plain text instead of JSON.
- Running `events` with no command shows help instead of an error.
- `events status` returns only authorization status; command documentation moved into `-h`.
- Debug output goes to stderr so the JSON stdout stream stays clean.
