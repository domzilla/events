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
            availableCommands: self.commandList()
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

    private static func commandList() -> [CommandInfoDTO] {
        [
            CommandInfoDTO(
                command: "events status",
                description: "Show authorization status and available commands"
            ),
            CommandInfoDTO(
                command: "events calendars list",
                description: "List all calendars"
            ),
            CommandInfoDTO(
                command: "events list --date <iso8601>",
                description: "List events for a specific date"
            ),
            CommandInfoDTO(
                command: "events list --from <iso8601> [--to <iso8601>] [--calendar <id>]",
                description: "List events in a date range (--to defaults to +30 days)"
            ),
            CommandInfoDTO(
                command: "events search --query <keyword> [--from <iso8601>] [--to <iso8601>] [--calendar <id>]",
                description: "Search events by keyword across title, location, and notes"
            ),
            CommandInfoDTO(
                command: "events get <identifier>",
                description: "Get a single event by identifier"
            ),
            CommandInfoDTO(
                command: "events create --title <t> --start <iso8601> --end <iso8601> --calendar <id> [--all-day] [--location <s>] [--notes <s>] [--url <s>] [--alarm <minutes>] [--recurrence daily|weekly|monthly|yearly] [--recurrence-interval <n>] [--recurrence-end <iso8601>] [--recurrence-count <n>]",
                description: "Create a new event"
            ),
            CommandInfoDTO(
                command: "events update <identifier> [--title <t>] [--start <iso8601>] [--end <iso8601>] [--calendar <id>] [--location <s>] [--notes <s>] [--all-day <bool>] [--alarm <minutes>] [--span this|future]",
                description: "Update an existing event"
            ),
            CommandInfoDTO(
                command: "events delete <identifier> [--span this|future]",
                description: "Delete an event"
            ),
            CommandInfoDTO(
                command: "events reminders list [--calendar <id>] [--completed | --incomplete] [--due-before <iso8601>] [--due-after <iso8601>]",
                description: "List reminders with optional filters"
            ),
            CommandInfoDTO(
                command: "events reminders list --overdue",
                description: "List overdue incomplete reminders"
            ),
            CommandInfoDTO(
                command: "events reminders search --query <keyword> [--calendar <id>]",
                description: "Search reminders by keyword"
            ),
            CommandInfoDTO(
                command: "events reminders get <identifier>",
                description: "Get a single reminder by identifier"
            ),
            CommandInfoDTO(
                command: "events reminders create --title <t> --calendar <id> [--due <iso8601>] [--priority 0-9] [--notes <s>] [--alarm <minutes>]",
                description: "Create a new reminder"
            ),
            CommandInfoDTO(
                command: "events reminders update <identifier> [--title <t>] [--due <iso8601>] [--priority 0-9] [--notes <s>] [--alarm <minutes>]",
                description: "Update an existing reminder"
            ),
            CommandInfoDTO(
                command: "events reminders delete <identifier>",
                description: "Delete a reminder"
            ),
            CommandInfoDTO(
                command: "events reminders complete <identifier>",
                description: "Mark a reminder as completed"
            ),
        ]
    }

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
