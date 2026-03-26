# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `--alarm <minutes>` flag on `events update` and `events reminders update` commands
- `isSubscribed` and `isImmutable` fields to calendar JSON output
- Recurrence support for `events create`: `--recurrence daily|weekly|monthly|yearly`, `--recurrence-interval`, `--recurrence-end`, `--recurrence-count`
- Hierarchical help system: `events -h` for command overview, `<command> -h` for detailed per-command help with parameters and output schema
- `-h` and `--help` flags supported on all commands and subcommands
- Help hint (`Use 'events -h' for help.`) appended to all error output on stderr

### Changed
- Help output (`-h`/`--help`) now uses human-readable plain text format instead of JSON
- Running `events` with no command now shows help instead of an error
- Error messages for positional arguments now show `<identifier>` instead of `--identifier`
- Removed stale "Run 'events status' for available commands" from unknown command error
- `events status` now returns only authorization status (no longer includes command docs)

### Changed
- Replaced DZFoundation logging with CLI-specific Logger that writes to stderr
- Debug output no longer pollutes stdout JSON stream
- Removed DZFoundation dependency entirely

### Added
- CLI skeleton with JSON output envelope (`{"success": true/false, ...}`) and typed exit codes
- `events status` — show authorization status and full command reference
- `events calendars list` — list all event and reminder calendars with identifiers, types, colors
- `events list` — list events by `--date`, `--from`/`--to` date range, with optional `--calendar` filter
- `events search --query <keyword>` — search events by title, location, and notes (client-side filtering)
- `events get <identifier>` — get a single event by identifier
- `events create` — create events with title, start/end dates, calendar (required), location, notes, URL, alarm
- `events update <identifier>` — update event properties with `--span this|future` for recurring events
- `events delete <identifier>` — delete events with `--span this|future` support
- `events reminders list` — list reminders with `--completed`/`--incomplete`/`--overdue`, `--due-before`/`--due-after` filters
- `events reminders search --query <keyword>` — search reminders by title, location, and notes
- `events reminders get <identifier>` — get a single reminder by identifier
- `events reminders create` — create reminders with title, calendar (required), due date, priority, notes, alarm
- `events reminders update <identifier>` — update reminder properties
- `events reminders delete <identifier>` — delete a reminder
- `events reminders complete <identifier>` — mark a reminder as completed
- EventStoreManager with TCC authorization flow for calendar and reminder access
- ISO 8601 date parsing with full datetime, fractional seconds, and date-only support
