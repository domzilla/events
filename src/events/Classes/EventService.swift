//
//  EventService.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import EventKit
import Foundation

@MainActor
final class EventService {
    // MARK: - Properties

    private let manager: EventStoreManager

    // MARK: - Init

    init(manager: EventStoreManager) {
        self.manager = manager
    }

    // MARK: - List

    func listEvents(from startDate: Date, to endDate: Date, calendarID: String? = nil) throws -> [EventDTO] {
        let calendars = self.resolveCalendars(calendarID: calendarID, entityType: .event)
        let predicate = self.manager.store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = self.manager.store.events(matching: predicate)

        Logger.debug(
            "Found \(events.count) events between \(DateParsing.formatISO8601(startDate)) and \(DateParsing.formatISO8601(endDate))"
        )
        return events.map { EventDTO.from($0) }
    }

    // MARK: - Search

    func searchEvents(
        query: String,
        from startDate: Date?,
        to endDate: Date?,
        calendarID: String? = nil
    ) throws
        -> [EventDTO]
    {
        let effectiveStart = startDate ?? Date()
        let effectiveEnd = endDate ?? Calendar.current
            .date(byAdding: .day, value: 30, to: effectiveStart) ?? effectiveStart

        let calendars = self.resolveCalendars(calendarID: calendarID, entityType: .event)
        let predicate = self.manager.store.predicateForEvents(
            withStart: effectiveStart,
            end: effectiveEnd,
            calendars: calendars
        )
        let events = self.manager.store.events(matching: predicate)

        let lowercaseQuery = query.lowercased()
        let filtered = events.filter { event in
            if event.title?.lowercased().contains(lowercaseQuery) == true { return true }
            if event.location?.lowercased().contains(lowercaseQuery) == true { return true }
            if event.notes?.lowercased().contains(lowercaseQuery) == true { return true }
            return false
        }

        Logger.debug("Search '\(query)' found \(filtered.count) matching events out of \(events.count) total")
        return filtered.map { EventDTO.from($0) }
    }

    // MARK: - Get

    func getEvent(identifier: String) throws -> EventDTO {
        guard let event = self.manager.store.event(withIdentifier: identifier) else {
            throw EventsError.notFound(type: "Event", identifier: identifier)
        }
        return EventDTO.from(event)
    }

    // MARK: - Create

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        calendarID: String,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: String? = nil,
        alarmMinutes: Int? = nil,
        recurrence: EKRecurrenceFrequency? = nil,
        recurrenceInterval: Int = 1,
        recurrenceEnd: EKRecurrenceEnd? = nil
    ) throws
        -> EventDTO
    {
        guard let calendar = self.manager.store.calendar(withIdentifier: calendarID) else {
            throw EventsError.notFound(type: "Calendar", identifier: calendarID)
        }

        guard calendar.allowsContentModifications else {
            throw EventsError.calendarReadOnly(identifier: calendarID)
        }

        let event = EKEvent(eventStore: self.manager.store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.isAllDay = isAllDay

        if let location { event.location = location }
        if let notes { event.notes = notes }
        if let url, let parsedURL = URL(string: url) { event.url = parsedURL }

        if let minutes = alarmMinutes {
            let alarm = EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            event.addAlarm(alarm)
        }

        if let recurrence {
            let rule = EKRecurrenceRule(
                recurrenceWith: recurrence,
                interval: recurrenceInterval,
                end: recurrenceEnd
            )
            event.addRecurrenceRule(rule)
        }

        try self.manager.store.save(event, span: .thisEvent, commit: true)
        Logger.debug("Created event: \(title) (\(event.eventIdentifier ?? "no-id"))")
        return EventDTO.from(event)
    }

    // MARK: - Update

    func updateEvent(
        identifier: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        calendarID: String? = nil,
        isAllDay: Bool? = nil,
        location: String? = nil,
        notes: String? = nil,
        alarmMinutes: Int? = nil,
        span: EKSpan = .thisEvent
    ) throws
        -> EventDTO
    {
        guard let event = self.manager.store.event(withIdentifier: identifier) else {
            throw EventsError.notFound(type: "Event", identifier: identifier)
        }

        if let title { event.title = title }
        if let startDate { event.startDate = startDate }
        if let endDate { event.endDate = endDate }
        if let isAllDay { event.isAllDay = isAllDay }
        if let location { event.location = location }
        if let notes { event.notes = notes }

        if let minutes = alarmMinutes {
            if let existing = event.alarms {
                for alarm in existing {
                    event.removeAlarm(alarm)
                }
            }
            let alarm = EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
            event.addAlarm(alarm)
        }

        if let calendarID {
            guard let calendar = self.manager.store.calendar(withIdentifier: calendarID) else {
                throw EventsError.notFound(type: "Calendar", identifier: calendarID)
            }
            guard calendar.allowsContentModifications else {
                throw EventsError.calendarReadOnly(identifier: calendarID)
            }
            event.calendar = calendar
        }

        try self.manager.store.save(event, span: span, commit: true)
        Logger.debug("Updated event: \(event.title ?? identifier)")
        return EventDTO.from(event)
    }

    // MARK: - Delete

    func deleteEvent(identifier: String, span: EKSpan = .thisEvent) throws {
        guard let event = self.manager.store.event(withIdentifier: identifier) else {
            throw EventsError.notFound(type: "Event", identifier: identifier)
        }

        let title = event.title ?? identifier
        try self.manager.store.remove(event, span: span, commit: true)
        Logger.debug("Deleted event: \(title)")
    }

    // MARK: - Private

    private func resolveCalendars(calendarID: String?, entityType _: EKEntityType) -> [EKCalendar]? {
        guard let calendarID else { return nil }
        if let calendar = self.manager.store.calendar(withIdentifier: calendarID) {
            return [calendar]
        }
        return nil
    }
}
