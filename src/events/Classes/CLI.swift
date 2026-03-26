//
//  CLI.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import EventKit
import Foundation

@MainActor
enum CLI {
    // MARK: - Run

    static func run(arguments: [String]) async {
        let args = Array(arguments.dropFirst())

        guard let command = args.first else {
            JSONOutput.error(.unknownCommand(command: ""))
        }

        Logger.debug("Command: \(args.joined(separator: " "))")

        switch command {
        case "status":
            await self.handleStatus()

        case "calendars":
            guard args.count > 1, args[1] == "list" else {
                JSONOutput.error(.unknownCommand(command: "calendars \(args.dropFirst().first ?? "")"))
            }
            await self.handleCalendarsList()

        case "list":
            await self.handleEventsList(args: args)

        case "search":
            await self.handleEventsSearch(args: args)

        case "get":
            await self.handleEventsGet(args: args)

        case "create":
            await self.handleEventsCreate(args: args)

        case "update":
            await self.handleEventsUpdate(args: args)

        case "delete":
            await self.handleEventsDelete(args: args)

        case "reminders":
            guard args.count > 1 else {
                JSONOutput.error(.unknownCommand(command: "reminders"))
            }
            let subArgs = Array(args.dropFirst())
            switch args[1] {
            case "list":
                await self.handleRemindersList(args: subArgs)
            case "search":
                await self.handleRemindersSearch(args: subArgs)
            case "get":
                await self.handleRemindersGet(args: subArgs)
            case "create":
                await self.handleRemindersCreate(args: subArgs)
            case "update":
                await self.handleRemindersUpdate(args: subArgs)
            case "delete":
                await self.handleRemindersDelete(args: subArgs)
            case "complete":
                await self.handleRemindersComplete(args: subArgs)
            default:
                JSONOutput.error(.unknownCommand(command: "reminders \(args[1])"))
            }

        default:
            JSONOutput.error(.unknownCommand(command: command))
        }
    }

    // MARK: - Status

    private static func handleStatus() async {
        let manager = EventStoreManager.shared
        let status = StatusDTO(
            eventsAuthorization: manager.eventsAuthorizationStatus.displayString,
            remindersAuthorization: manager.remindersAuthorizationStatus.displayString,
            exitCodes: [
                "success": 0,
                "general_error": 1,
                "authorization_denied": 2,
                "not_found": 3,
                "validation_error": 4,
                "calendar_read_only": 5,
            ],
            dateFormat: "ISO 8601 (e.g. 2026-03-26T10:00:00Z or 2026-03-26)",
            commands: self.commandList()
        )
        JSONOutput.success(status)
    }

    // MARK: - Calendars

    private static func handleCalendarsList() async {
        do {
            let service = CalendarService(manager: EventStoreManager.shared)
            let calendars = try await service.listCalendars()
            JSONOutput.success(calendars)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Events List

    private static func handleEventsList(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureEventsAccess()
            let service = EventService(manager: manager)
            let calendarID = self.flagValue(for: "calendar", in: args)

            let startDate: Date
            let endDate: Date

            if let dateStr = self.flagValue(for: "date", in: args) {
                let date = try DateParsing.parseISO8601(dateStr)
                startDate = DateParsing.startOfDay(date)
                endDate = DateParsing.endOfDay(date)
            } else if let fromStr = self.flagValue(for: "from", in: args) {
                startDate = try DateParsing.parseISO8601(fromStr)
                if let toStr = self.flagValue(for: "to", in: args) {
                    endDate = try DateParsing.parseISO8601(toStr)
                } else {
                    endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
                }
            } else if let toStr = self.flagValue(for: "to", in: args) {
                endDate = try DateParsing.parseISO8601(toStr)
                startDate = Date()
            } else {
                JSONOutput
                    .error(.validationError(message: "Provide --date <iso8601> or --from <iso8601> [--to <iso8601>]"))
            }

            let events = try service.listEvents(from: startDate, to: endDate, calendarID: calendarID)
            JSONOutput.success(events)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Events Search

    private static func handleEventsSearch(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureEventsAccess()
            let service = EventService(manager: manager)

            let query = try self.requiredFlagValue(for: "query", in: args)
            let calendarID = self.flagValue(for: "calendar", in: args)
            let fromDate = try self.flagValue(for: "from", in: args).map { try DateParsing.parseISO8601($0) }
            let toDate = try self.flagValue(for: "to", in: args).map { try DateParsing.parseISO8601($0) }

            let events = try service.searchEvents(query: query, from: fromDate, to: toDate, calendarID: calendarID)
            JSONOutput.success(events)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Events Get

    private static func handleEventsGet(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureEventsAccess()
            let service = EventService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            let event = try service.getEvent(identifier: identifier)
            JSONOutput.success(event)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Events Create

    private static func handleEventsCreate(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureEventsAccess()
            let service = EventService(manager: manager)

            let title = try self.requiredFlagValue(for: "title", in: args)
            let startStr = try self.requiredFlagValue(for: "start", in: args)
            let endStr = try self.requiredFlagValue(for: "end", in: args)
            let calendarID = try self.requiredFlagValue(for: "calendar", in: args)

            let startDate = try DateParsing.parseISO8601(startStr)
            let endDate = try DateParsing.parseISO8601(endStr)
            let isAllDay = self.hasFlag("all-day", in: args)
            let location = self.flagValue(for: "location", in: args)
            let notes = self.flagValue(for: "notes", in: args)
            let url = self.flagValue(for: "url", in: args)
            let alarmMinutes = self.flagValue(for: "alarm", in: args).flatMap { Int($0) }

            let recurrence = self.flagValue(for: "recurrence", in: args)
                .flatMap { self.parseRecurrenceFrequency($0) }
            let recurrenceInterval = self.flagValue(for: "recurrence-interval", in: args)
                .flatMap { Int($0) } ?? 1
            let recurrenceEnd: EKRecurrenceEnd? = try {
                if let endDateStr = self.flagValue(for: "recurrence-end", in: args) {
                    return try EKRecurrenceEnd(end: DateParsing.parseISO8601(endDateStr))
                }
                if let count = self.flagValue(for: "recurrence-count", in: args).flatMap({ Int($0) }) {
                    return EKRecurrenceEnd(occurrenceCount: count)
                }
                return nil
            }()

            let event = try service.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarID: calendarID,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                url: url,
                alarmMinutes: alarmMinutes,
                recurrence: recurrence,
                recurrenceInterval: recurrenceInterval,
                recurrenceEnd: recurrenceEnd
            )
            JSONOutput.success(event)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Events Update

    private static func handleEventsUpdate(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureEventsAccess()
            let service = EventService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            let title = self.flagValue(for: "title", in: args)
            let startDate = try self.flagValue(for: "start", in: args).map { try DateParsing.parseISO8601($0) }
            let endDate = try self.flagValue(for: "end", in: args).map { try DateParsing.parseISO8601($0) }
            let calendarID = self.flagValue(for: "calendar", in: args)
            let location = self.flagValue(for: "location", in: args)
            let notes = self.flagValue(for: "notes", in: args)
            let isAllDay: Bool? = self.flagValue(for: "all-day", in: args).map { $0 == "true" }
            let alarmMinutes = self.flagValue(for: "alarm", in: args).flatMap { Int($0) }

            let spanStr = self.flagValue(for: "span", in: args)
            let span: EKSpan = spanStr == "future" ? .futureEvents : .thisEvent

            let event = try service.updateEvent(
                identifier: identifier,
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarID: calendarID,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                alarmMinutes: alarmMinutes,
                span: span
            )
            JSONOutput.success(event)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Events Delete

    private static func handleEventsDelete(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureEventsAccess()
            let service = EventService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            let spanStr = self.flagValue(for: "span", in: args)
            let span: EKSpan = spanStr == "future" ? .futureEvents : .thisEvent

            try service.deleteEvent(identifier: identifier, span: span)
            JSONOutput.success(DeletedDTO(deleted: true, identifier: identifier))
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders List

    private static func handleRemindersList(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)
            let calendarID = self.flagValue(for: "calendar", in: args)

            let filter: ReminderFilter = if self.hasFlag("overdue", in: args) {
                .overdue
            } else if self.hasFlag("completed", in: args) {
                .completed
            } else if self.hasFlag("incomplete", in: args) {
                .incomplete
            } else {
                .all
            }

            let dueBefore = try self.flagValue(for: "due-before", in: args)
                .map { try DateParsing.parseISO8601($0) }
            let dueAfter = try self.flagValue(for: "due-after", in: args)
                .map { try DateParsing.parseISO8601($0) }

            let reminders = try await service.listReminders(
                calendarID: calendarID,
                filter: filter,
                dueBefore: dueBefore,
                dueAfter: dueAfter
            )
            JSONOutput.success(reminders)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders Search

    private static func handleRemindersSearch(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)

            let query = try self.requiredFlagValue(for: "query", in: args)
            let calendarID = self.flagValue(for: "calendar", in: args)

            let reminders = try await service.searchReminders(query: query, calendarID: calendarID)
            JSONOutput.success(reminders)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders Get

    private static func handleRemindersGet(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            let reminder = try service.getReminder(identifier: identifier)
            JSONOutput.success(reminder)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders Create

    private static func handleRemindersCreate(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)

            let title = try self.requiredFlagValue(for: "title", in: args)
            let calendarID = try self.requiredFlagValue(for: "calendar", in: args)
            let dueDate = try self.flagValue(for: "due", in: args).map { try DateParsing.parseISO8601($0) }
            let priority = self.flagValue(for: "priority", in: args).flatMap { Int($0) }
            let notes = self.flagValue(for: "notes", in: args)
            let alarmMinutes = self.flagValue(for: "alarm", in: args).flatMap { Int($0) }

            let reminder = try service.createReminder(
                title: title,
                calendarID: calendarID,
                dueDate: dueDate,
                priority: priority,
                notes: notes,
                alarmMinutes: alarmMinutes
            )
            JSONOutput.success(reminder)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders Update

    private static func handleRemindersUpdate(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            let title = self.flagValue(for: "title", in: args)
            let dueDate = try self.flagValue(for: "due", in: args).map { try DateParsing.parseISO8601($0) }
            let priority = self.flagValue(for: "priority", in: args).flatMap { Int($0) }
            let notes = self.flagValue(for: "notes", in: args)
            let alarmMinutes = self.flagValue(for: "alarm", in: args).flatMap { Int($0) }

            let reminder = try service.updateReminder(
                identifier: identifier,
                title: title,
                dueDate: dueDate,
                priority: priority,
                notes: notes,
                alarmMinutes: alarmMinutes
            )
            JSONOutput.success(reminder)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders Delete

    private static func handleRemindersDelete(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            try service.deleteReminder(identifier: identifier)
            JSONOutput.success(DeletedDTO(deleted: true, identifier: identifier))
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Reminders Complete

    private static func handleRemindersComplete(args: [String]) async {
        do {
            let manager = EventStoreManager.shared
            try await manager.ensureRemindersAccess()
            let service = ReminderService(manager: manager)

            guard let identifier = self.positionalArgument(at: 1, in: args) else {
                JSONOutput.error(.missingRequiredArgument(name: "identifier"))
            }

            let reminder = try service.completeReminder(identifier: identifier)
            JSONOutput.success(reminder)
        } catch let error as EventsError {
            JSONOutput.error(error)
        } catch {
            JSONOutput.error(.eventKitError(underlying: error))
        }
    }

    // MARK: - Command List

    // swiftlint:disable function_body_length
    private static func commandList() -> [CommandInfoDTO] {
        let calendarFields: [String: String] = [
            "identifier": "Unique calendar ID (use this for --calendar flags)",
            "title": "Calendar display name",
            "type": "Calendar type: local, caldav, exchange, subscription, birthday",
            "entityType": "What this calendar holds: event or reminder",
            "sourceName": "Account name (e.g. iCloud, Exchange)",
            "color": "Hex color code (#RRGGBB)",
            "isReadOnly": "Whether items can be added/edited/deleted",
            "isSubscribed": "Whether this is a subscribed calendar",
            "isImmutable": "Whether the calendar itself can be modified",
        ]

        let eventFields: [String: String] = [
            "identifier": "Unique event ID (use this for get/update/delete)",
            "title": "Event title",
            "startDate": "Start date/time (ISO 8601)",
            "endDate": "End date/time (ISO 8601)",
            "isAllDay": "Whether this is an all-day event",
            "calendar": "Object with identifier and title of the containing calendar",
            "location": "Location string or null",
            "notes": "Notes/description or null",
            "url": "Associated URL or null",
            "availability": "Scheduling availability: busy, free, tentative, unavailable, not_supported",
            "status": "Event status: none, confirmed, tentative, canceled",
            "isDetached": "Whether this is a modified occurrence of a recurring event",
            "hasRecurrenceRules": "Whether this event repeats",
            "hasAlarms": "Whether alarms are set",
            "hasAttendees": "Whether there are attendees",
            "alarms": "Array of alarms with relativeOffset (seconds) or absoluteDate",
            "attendees": "Array of attendees with name, status, role, type, isCurrentUser",
            "creationDate": "When the event was created (ISO 8601) or null",
            "lastModifiedDate": "When the event was last modified (ISO 8601) or null",
        ]

        let reminderFields: [String: String] = [
            "identifier": "Unique reminder ID (use this for get/update/delete/complete)",
            "title": "Reminder title",
            "calendar": "Object with identifier and title of the containing calendar",
            "isCompleted": "Whether the reminder is marked as done",
            "completionDate": "When it was completed (ISO 8601) or null",
            "dueDate": "Due date (ISO 8601) or null",
            "startDate": "Start date (ISO 8601) or null",
            "priority": "Priority 0-9 (0=none, 1-4=high, 5=medium, 6-8=low, 9=low)",
            "notes": "Notes/description or null",
            "hasAlarms": "Whether alarms are set",
            "hasRecurrenceRules": "Whether this reminder repeats",
            "creationDate": "When the reminder was created (ISO 8601) or null",
            "lastModifiedDate": "When the reminder was last modified (ISO 8601) or null",
        ]

        return [
            // MARK: Status

            CommandInfoDTO(
                command: "events status",
                description: "Show authorization status, exit codes, date format, and full command reference.",
                parameters: nil,
                output: OutputInfoDTO(
                    description: "Authorization status and command documentation",
                    fields: [
                        "eventsAuthorization": "Authorization for calendar events: not_determined, denied, restricted, full_access, write_only",
                        "remindersAuthorization": "Authorization for reminders: not_determined, denied, restricted, full_access, write_only",
                        "exitCodes": "Map of error type to exit code number",
                        "dateFormat": "Expected date format for all date parameters",
                        "commands": "Array of all available commands with parameters and output schemas",
                    ]
                )
            ),

            // MARK: Calendars

            CommandInfoDTO(
                command: "events calendars list",
                description: "List all calendars the user has access to, including both event and reminder calendars.",
                parameters: nil,
                output: OutputInfoDTO(
                    description: "Array of calendar objects",
                    fields: calendarFields
                )
            ),

            // MARK: Events - List

            CommandInfoDTO(
                command: "events list",
                description: "List events in a date range. Use --date for a single day, or --from/--to for a range. At least one date parameter is required.",
                parameters: [
                    ParameterInfoDTO(
                        name: "--date",
                        type: "ISO 8601 date",
                        required: false,
                        description: "List events for a single day (midnight to midnight). Cannot combine with --from/--to."
                    ),
                    ParameterInfoDTO(
                        name: "--from",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "Start of date range. If --to is omitted, defaults to +30 days."
                    ),
                    ParameterInfoDTO(
                        name: "--to",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "End of date range. If --from is omitted, defaults to now."
                    ),
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: false,
                        description: "Filter to a specific calendar. Use identifier from 'calendars list'."
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Array of event objects sorted by start date",
                    fields: eventFields
                )
            ),

            // MARK: Events - Search

            CommandInfoDTO(
                command: "events search",
                description: "Search events by keyword. Matches against title, location, and notes fields (case-insensitive). Searches within a date range (defaults to now +30 days).",
                parameters: [
                    ParameterInfoDTO(
                        name: "--query",
                        type: "string",
                        required: true,
                        description: "Search keyword to match against title, location, and notes"
                    ),
                    ParameterInfoDTO(
                        name: "--from",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "Start of search range (defaults to now)"
                    ),
                    ParameterInfoDTO(
                        name: "--to",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "End of search range (defaults to --from +30 days)"
                    ),
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: false,
                        description: "Filter to a specific calendar"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Array of matching event objects",
                    fields: eventFields
                )
            ),

            // MARK: Events - Get

            CommandInfoDTO(
                command: "events get <identifier>",
                description: "Get a single event by its identifier. Use the identifier from list or search results.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Event identifier (positional argument, not a flag)"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Single event object",
                    fields: eventFields
                )
            ),

            // MARK: Events - Create

            CommandInfoDTO(
                command: "events create",
                description: "Create a new calendar event. Returns the created event with its assigned identifier.",
                parameters: [
                    ParameterInfoDTO(name: "--title", type: "string", required: true, description: "Event title"),
                    ParameterInfoDTO(
                        name: "--start",
                        type: "ISO 8601 datetime",
                        required: true,
                        description: "Event start date/time"
                    ),
                    ParameterInfoDTO(
                        name: "--end",
                        type: "ISO 8601 datetime",
                        required: true,
                        description: "Event end date/time (must be after start)"
                    ),
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: true,
                        description: "Target calendar (must not be read-only)"
                    ),
                    ParameterInfoDTO(
                        name: "--all-day",
                        type: "flag",
                        required: false,
                        description: "Mark as all-day event (no value needed)"
                    ),
                    ParameterInfoDTO(
                        name: "--location",
                        type: "string",
                        required: false,
                        description: "Event location"
                    ),
                    ParameterInfoDTO(
                        name: "--notes",
                        type: "string",
                        required: false,
                        description: "Event notes/description"
                    ),
                    ParameterInfoDTO(name: "--url", type: "URL string", required: false, description: "Associated URL"),
                    ParameterInfoDTO(
                        name: "--alarm",
                        type: "integer (minutes)",
                        required: false,
                        description: "Add alarm N minutes before event start"
                    ),
                    ParameterInfoDTO(
                        name: "--recurrence",
                        type: "daily|weekly|monthly|yearly",
                        required: false,
                        description: "Make this a recurring event"
                    ),
                    ParameterInfoDTO(
                        name: "--recurrence-interval",
                        type: "integer",
                        required: false,
                        description: "Repeat every N periods (default 1). E.g. --recurrence weekly --recurrence-interval 2 = every 2 weeks."
                    ),
                    ParameterInfoDTO(
                        name: "--recurrence-end",
                        type: "ISO 8601 date",
                        required: false,
                        description: "Stop recurring after this date"
                    ),
                    ParameterInfoDTO(
                        name: "--recurrence-count",
                        type: "integer",
                        required: false,
                        description: "Stop recurring after N occurrences"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "The created event object with its new identifier",
                    fields: eventFields
                )
            ),

            // MARK: Events - Update

            CommandInfoDTO(
                command: "events update <identifier>",
                description: "Update an existing event. Only the fields you provide will be changed; all other fields remain unchanged. For recurring events, use --span to control scope.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Event identifier (positional argument)"
                    ),
                    ParameterInfoDTO(name: "--title", type: "string", required: false, description: "New title"),
                    ParameterInfoDTO(
                        name: "--start",
                        type: "ISO 8601 datetime",
                        required: false,
                        description: "New start date/time"
                    ),
                    ParameterInfoDTO(
                        name: "--end",
                        type: "ISO 8601 datetime",
                        required: false,
                        description: "New end date/time"
                    ),
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: false,
                        description: "Move event to a different calendar"
                    ),
                    ParameterInfoDTO(name: "--location", type: "string", required: false, description: "New location"),
                    ParameterInfoDTO(name: "--notes", type: "string", required: false, description: "New notes"),
                    ParameterInfoDTO(
                        name: "--all-day",
                        type: "true|false",
                        required: false,
                        description: "Change all-day status"
                    ),
                    ParameterInfoDTO(
                        name: "--alarm",
                        type: "integer (minutes)",
                        required: false,
                        description: "Replace all alarms with one N minutes before start"
                    ),
                    ParameterInfoDTO(
                        name: "--span",
                        type: "this|future",
                        required: false,
                        description: "For recurring events: 'this' = only this occurrence (default), 'future' = this and all future occurrences"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "The updated event object",
                    fields: eventFields
                )
            ),

            // MARK: Events - Delete

            CommandInfoDTO(
                command: "events delete <identifier>",
                description: "Delete an event. For recurring events, use --span to control whether to delete just this occurrence or all future occurrences.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Event identifier (positional argument)"
                    ),
                    ParameterInfoDTO(
                        name: "--span",
                        type: "this|future",
                        required: false,
                        description: "For recurring events: 'this' = only this occurrence (default), 'future' = this and all future occurrences"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Confirmation object",
                    fields: [
                        "deleted": "Always true on success",
                        "identifier": "The identifier of the deleted event",
                    ]
                )
            ),

            // MARK: Reminders - List

            CommandInfoDTO(
                command: "events reminders list",
                description: "List reminders with optional filters. Without filters, returns all reminders. Filters can be combined.",
                parameters: [
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: false,
                        description: "Filter to a specific reminder calendar"
                    ),
                    ParameterInfoDTO(
                        name: "--completed",
                        type: "flag",
                        required: false,
                        description: "Show only completed reminders"
                    ),
                    ParameterInfoDTO(
                        name: "--incomplete",
                        type: "flag",
                        required: false,
                        description: "Show only incomplete reminders"
                    ),
                    ParameterInfoDTO(
                        name: "--overdue",
                        type: "flag",
                        required: false,
                        description: "Show only incomplete reminders past their due date"
                    ),
                    ParameterInfoDTO(
                        name: "--due-before",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "Show reminders due before this date"
                    ),
                    ParameterInfoDTO(
                        name: "--due-after",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "Show reminders due after this date"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Array of reminder objects",
                    fields: reminderFields
                )
            ),

            // MARK: Reminders - Search

            CommandInfoDTO(
                command: "events reminders search",
                description: "Search reminders by keyword. Matches against title, location, and notes fields (case-insensitive). Searches all reminders regardless of completion status.",
                parameters: [
                    ParameterInfoDTO(
                        name: "--query",
                        type: "string",
                        required: true,
                        description: "Search keyword to match against title, location, and notes"
                    ),
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: false,
                        description: "Filter to a specific reminder calendar"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Array of matching reminder objects",
                    fields: reminderFields
                )
            ),

            // MARK: Reminders - Get

            CommandInfoDTO(
                command: "events reminders get <identifier>",
                description: "Get a single reminder by its identifier.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Reminder identifier (positional argument)"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Single reminder object",
                    fields: reminderFields
                )
            ),

            // MARK: Reminders - Create

            CommandInfoDTO(
                command: "events reminders create",
                description: "Create a new reminder. Returns the created reminder with its assigned identifier.",
                parameters: [
                    ParameterInfoDTO(name: "--title", type: "string", required: true, description: "Reminder title"),
                    ParameterInfoDTO(
                        name: "--calendar",
                        type: "calendar identifier",
                        required: true,
                        description: "Target reminder calendar (must not be read-only)"
                    ),
                    ParameterInfoDTO(
                        name: "--due",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "Due date"
                    ),
                    ParameterInfoDTO(
                        name: "--priority",
                        type: "integer 0-9",
                        required: false,
                        description: "Priority: 0=none, 1-4=high, 5=medium, 6-9=low"
                    ),
                    ParameterInfoDTO(
                        name: "--notes",
                        type: "string",
                        required: false,
                        description: "Reminder notes/description"
                    ),
                    ParameterInfoDTO(
                        name: "--alarm",
                        type: "integer (minutes)",
                        required: false,
                        description: "Add alarm N minutes before due date"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "The created reminder object with its new identifier",
                    fields: reminderFields
                )
            ),

            // MARK: Reminders - Update

            CommandInfoDTO(
                command: "events reminders update <identifier>",
                description: "Update an existing reminder. Only the fields you provide will be changed; all other fields remain unchanged.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Reminder identifier (positional argument)"
                    ),
                    ParameterInfoDTO(name: "--title", type: "string", required: false, description: "New title"),
                    ParameterInfoDTO(
                        name: "--due",
                        type: "ISO 8601 date/datetime",
                        required: false,
                        description: "New due date"
                    ),
                    ParameterInfoDTO(
                        name: "--priority",
                        type: "integer 0-9",
                        required: false,
                        description: "New priority"
                    ),
                    ParameterInfoDTO(name: "--notes", type: "string", required: false, description: "New notes"),
                    ParameterInfoDTO(
                        name: "--alarm",
                        type: "integer (minutes)",
                        required: false,
                        description: "Replace all alarms with one N minutes before due date"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "The updated reminder object",
                    fields: reminderFields
                )
            ),

            // MARK: Reminders - Delete

            CommandInfoDTO(
                command: "events reminders delete <identifier>",
                description: "Delete a reminder permanently.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Reminder identifier (positional argument)"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "Confirmation object",
                    fields: [
                        "deleted": "Always true on success",
                        "identifier": "The identifier of the deleted reminder",
                    ]
                )
            ),

            // MARK: Reminders - Complete

            CommandInfoDTO(
                command: "events reminders complete <identifier>",
                description: "Mark a reminder as completed. Sets isCompleted to true and records the completion date.",
                parameters: [
                    ParameterInfoDTO(
                        name: "<identifier>",
                        type: "string",
                        required: true,
                        description: "Reminder identifier (positional argument)"
                    ),
                ],
                output: OutputInfoDTO(
                    description: "The updated reminder object with isCompleted=true",
                    fields: reminderFields
                )
            ),
        ]
    }

    // swiftlint:enable function_body_length

    // MARK: - Argument Parsing Helpers

    static func flagValue(for flag: String, in args: [String]) -> String? {
        let key = "--\(flag)"
        guard let index = args.firstIndex(of: key), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

    static func requiredFlagValue(for flag: String, in args: [String]) throws -> String {
        guard let value = self.flagValue(for: flag, in: args) else {
            throw EventsError.missingRequiredArgument(name: flag)
        }
        return value
    }

    static func hasFlag(_ flag: String, in args: [String]) -> Bool {
        args.contains("--\(flag)")
    }

    static func positionalArgument(at index: Int, in args: [String]) -> String? {
        guard index < args.count else { return nil }
        let value = args[index]
        guard !value.hasPrefix("--") else { return nil }
        return value
    }

    static func parseRecurrenceFrequency(_ value: String) -> EKRecurrenceFrequency? {
        switch value.lowercased() {
        case "daily": .daily
        case "weekly": .weekly
        case "monthly": .monthly
        case "yearly": .yearly
        default: nil
        }
    }
}
