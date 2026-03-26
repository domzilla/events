# events

A Swift CLI tool that wraps Apple's EventKit framework, enabling AI agents and scripts to interact with macOS Calendar and Reminders through structured JSON output.

## Install

```bash
brew tap domzilla/tap
brew install events
```

## Usage

All commands output JSON to stdout. Debug logging goes to stderr.

```bash
# Check authorization status
events status

# List calendars
events calendars list

# List events for a specific day
events list --date 2026-03-27

# List events in a date range
events list --from 2026-03-01 --to 2026-03-31

# Search events
events search --query "standup"

# Get a single event
events get <identifier>

# Create an event
events create --title "Meeting" --start 2026-03-27T09:00:00 --end 2026-03-27T10:00:00 --calendar <identifier>

# Create a recurring event
events create --title "Daily Standup" --start 2026-03-27T09:00:00 --end 2026-03-27T09:15:00 \
  --calendar <identifier> --recurrence daily --recurrence-end 2026-06-30

# Update an event
events update <identifier> --title "Renamed Meeting" --alarm 15

# Delete an event
events delete <identifier>
```

### Reminders

```bash
# List reminders
events reminders list --incomplete

# Create a reminder
events reminders create --title "Buy milk" --calendar <identifier> --due 2026-03-28 --priority 1

# Complete a reminder
events reminders complete <identifier>

# Search, get, update, delete
events reminders search --query "milk"
events reminders get <identifier>
events reminders update <identifier> --notes "Oat milk"
events reminders delete <identifier>
```

### Recurring events

Use `--span this|future` on update and delete to control whether changes apply to a single occurrence or all future occurrences. Use `--occurrence-date` on get, update, and delete to target a specific occurrence.

```bash
events update <identifier> --occurrence-date 2026-04-03 --title "Renamed" --span this
events delete <identifier> --span future
```

### Help

```bash
events -h              # Command overview
```

## JSON output

All responses use a consistent envelope:

```json
{
  "success": true,
  "data": { }
}
```

On failure:

```json
{
  "success": false,
  "error": "Description of what went wrong"
}
```

## Requirements

- macOS 14.0 or later
- Calendar and/or Reminders access (granted via TCC prompt on first run)

## Building from source

```bash
cd src
xcodebuild -scheme "events" -destination "platform=macOS" build
```

## License

[MIT](LICENSE)
