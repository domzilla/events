//
//  CalendarService.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZFoundation
import EventKit
import Foundation

@MainActor
final class CalendarService {
    // MARK: - Properties

    private let manager: EventStoreManager

    // MARK: - Init

    init(manager: EventStoreManager) {
        self.manager = manager
    }

    // MARK: - List

    func listCalendars() async throws -> [CalendarDTO] {
        try await self.manager.ensureEventsAccess()

        let eventCalendars = self.manager.store.calendars(for: .event)
        var calendarDTOs = eventCalendars.map { CalendarDTO.from($0, entityType: "event") }

        // Also fetch reminder calendars if we have access
        let reminderStatus = self.manager.remindersAuthorizationStatus
        if reminderStatus == .fullAccess {
            let reminderCalendars = self.manager.store.calendars(for: .reminder)
            calendarDTOs += reminderCalendars.map { CalendarDTO.from($0, entityType: "reminder") }
        } else if reminderStatus == .notDetermined {
            do {
                try await self.manager.ensureRemindersAccess()
                let reminderCalendars = self.manager.store.calendars(for: .reminder)
                calendarDTOs += reminderCalendars.map { CalendarDTO.from($0, entityType: "reminder") }
            } catch {
                DZLog("Reminders access not granted, skipping reminder calendars")
            }
        }

        DZLog("Found \(calendarDTOs.count) calendars")
        return calendarDTOs
    }
}
