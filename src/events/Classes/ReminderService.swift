//
//  ReminderService.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import EventKit
import Foundation

enum ReminderFilter {
    case all
    case completed
    case incomplete
    case overdue
}

@MainActor
final class ReminderService {
    // MARK: - Properties

    private let manager: EventStoreManager

    // MARK: - Init

    init(manager: EventStoreManager) {
        self.manager = manager
    }

    // MARK: - List

    func listReminders(
        calendarID: String? = nil,
        filter: ReminderFilter = .all,
        dueBefore: Date? = nil,
        dueAfter: Date? = nil
    ) async throws
        -> [ReminderDTO]
    {
        let calendars = self.resolveCalendars(calendarID: calendarID)

        let predicate: NSPredicate = switch filter {
        case .completed:
            self.manager.store.predicateForCompletedReminders(
                withCompletionDateStarting: dueAfter,
                ending: dueBefore,
                calendars: calendars
            )
        case .incomplete:
            self.manager.store.predicateForIncompleteReminders(
                withDueDateStarting: dueAfter,
                ending: dueBefore,
                calendars: calendars
            )
        case .overdue:
            self.manager.store.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: Date(),
                calendars: calendars
            )
        case .all:
            self.manager.store.predicateForReminders(in: calendars)
        }

        let reminders = await self.fetchReminders(matching: predicate)

        // Apply date filters for .all case (predicate doesn't support date filtering)
        var filtered = reminders
        if filter == .all {
            if let dueBefore {
                filtered = filtered.filter { reminder in
                    guard
                        let due = reminder.dueDateComponents,
                        let dueDate = Calendar.current.date(from: due) else { return true }
                    return dueDate <= dueBefore
                }
            }
            if let dueAfter {
                filtered = filtered.filter { reminder in
                    guard
                        let due = reminder.dueDateComponents,
                        let dueDate = Calendar.current.date(from: due) else { return true }
                    return dueDate >= dueAfter
                }
            }
        }

        Logger.debug("Found \(filtered.count) reminders")
        return filtered.map { ReminderDTO.from($0) }
    }

    // MARK: - Search

    func searchReminders(query: String, calendarID: String? = nil) async throws -> [ReminderDTO] {
        let calendars = self.resolveCalendars(calendarID: calendarID)
        let predicate = self.manager.store.predicateForReminders(in: calendars)
        let reminders = await self.fetchReminders(matching: predicate)

        let lowercaseQuery = query.lowercased()
        let filtered = reminders.filter { reminder in
            if reminder.title?.lowercased().contains(lowercaseQuery) == true { return true }
            if reminder.location?.lowercased().contains(lowercaseQuery) == true { return true }
            if reminder.notes?.lowercased().contains(lowercaseQuery) == true { return true }
            return false
        }

        Logger.debug("Search '\(query)' found \(filtered.count) matching reminders")
        return filtered.map { ReminderDTO.from($0) }
    }

    // MARK: - Get

    func getReminder(identifier: String) throws -> ReminderDTO {
        guard
            let item = self.manager.store.calendarItem(withIdentifier: identifier),
            let reminder = item as? EKReminder else
        {
            throw EventsError.notFound(type: "Reminder", identifier: identifier)
        }
        return ReminderDTO.from(reminder)
    }

    // MARK: - Create

    func createReminder(
        title: String,
        calendarID: String,
        dueDate: Date? = nil,
        priority: Int? = nil,
        notes: String? = nil,
        alarmMinutes: Int? = nil
    ) throws
        -> ReminderDTO
    {
        guard let calendar = self.manager.store.calendar(withIdentifier: calendarID) else {
            throw EventsError.notFound(type: "Calendar", identifier: calendarID)
        }

        guard calendar.allowsContentModifications else {
            throw EventsError.calendarReadOnly(identifier: calendarID)
        }

        let reminder = EKReminder(eventStore: self.manager.store)
        reminder.title = title
        reminder.calendar = calendar

        if let dueDate {
            reminder.dueDateComponents = DateParsing.dateComponents(from: dueDate)
        }

        if let priority {
            reminder.priority = max(0, min(9, priority))
        }

        if let notes {
            reminder.notes = notes
        }

        if let minutes = alarmMinutes {
            let alarm = EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            reminder.addAlarm(alarm)
        }

        try self.manager.store.save(reminder, commit: true)
        Logger.debug("Created reminder: \(title) (\(reminder.calendarItemIdentifier))")
        return ReminderDTO.from(reminder)
    }

    // MARK: - Update

    func updateReminder(
        identifier: String,
        title: String? = nil,
        dueDate: Date? = nil,
        priority: Int? = nil,
        notes: String? = nil,
        alarmMinutes: Int? = nil
    ) throws
        -> ReminderDTO
    {
        guard
            let item = self.manager.store.calendarItem(withIdentifier: identifier),
            let reminder = item as? EKReminder else
        {
            throw EventsError.notFound(type: "Reminder", identifier: identifier)
        }

        if let title { reminder.title = title }
        if let dueDate { reminder.dueDateComponents = DateParsing.dateComponents(from: dueDate) }
        if let priority { reminder.priority = max(0, min(9, priority)) }
        if let notes { reminder.notes = notes }

        if let minutes = alarmMinutes {
            if let existing = reminder.alarms {
                for alarm in existing {
                    reminder.removeAlarm(alarm)
                }
            }
            let alarm = EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            reminder.addAlarm(alarm)
        }

        try self.manager.store.save(reminder, commit: true)
        Logger.debug("Updated reminder: \(reminder.title ?? identifier)")
        return ReminderDTO.from(reminder)
    }

    // MARK: - Delete

    func deleteReminder(identifier: String) throws {
        guard
            let item = self.manager.store.calendarItem(withIdentifier: identifier),
            let reminder = item as? EKReminder else
        {
            throw EventsError.notFound(type: "Reminder", identifier: identifier)
        }

        let title = reminder.title ?? identifier
        try self.manager.store.remove(reminder, commit: true)
        Logger.debug("Deleted reminder: \(title)")
    }

    // MARK: - Complete

    func completeReminder(identifier: String) throws -> ReminderDTO {
        guard
            let item = self.manager.store.calendarItem(withIdentifier: identifier),
            let reminder = item as? EKReminder else
        {
            throw EventsError.notFound(type: "Reminder", identifier: identifier)
        }

        reminder.isCompleted = true
        try self.manager.store.save(reminder, commit: true)
        Logger.debug("Completed reminder: \(reminder.title ?? identifier)")
        return ReminderDTO.from(reminder)
    }

    // MARK: - Private

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            self.manager.store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func resolveCalendars(calendarID: String?) -> [EKCalendar]? {
        guard let calendarID else { return nil }
        if let calendar = self.manager.store.calendar(withIdentifier: calendarID) {
            return [calendar]
        }
        return nil
    }
}
