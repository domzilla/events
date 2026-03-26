//
//  EventStoreManager.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import DZFoundation
import EventKit
import Foundation

@MainActor
final class EventStoreManager {
    // MARK: - Shared

    static let shared = EventStoreManager()

    // MARK: - Properties

    let store: EKEventStore

    // MARK: - Init

    private init() {
        self.store = EKEventStore()
    }

    // MARK: - Authorization

    var eventsAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var remindersAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    func ensureEventsAccess() async throws {
        let status = self.eventsAuthorizationStatus
        DZLog("Events authorization status: \(status.rawValue)")

        switch status {
        case .fullAccess:
            return
        case .notDetermined:
            let granted = try await self.store.requestFullAccessToEvents()
            if !granted {
                throw EventsError.authorizationDenied(entity: "calendar events")
            }
        case .denied, .restricted, .writeOnly:
            throw EventsError.authorizationDenied(entity: "calendar events")
        @unknown default:
            throw EventsError.authorizationDenied(entity: "calendar events")
        }
    }

    func ensureRemindersAccess() async throws {
        let status = self.remindersAuthorizationStatus
        DZLog("Reminders authorization status: \(status.rawValue)")

        switch status {
        case .fullAccess:
            return
        case .notDetermined:
            let granted = try await self.store.requestFullAccessToReminders()
            if !granted {
                throw EventsError.authorizationDenied(entity: "reminders")
            }
        case .denied, .restricted, .writeOnly:
            throw EventsError.authorizationDenied(entity: "reminders")
        @unknown default:
            throw EventsError.authorizationDenied(entity: "reminders")
        }
    }
}

// MARK: - EKAuthorizationStatus Helpers

extension EKAuthorizationStatus {
    var displayString: String {
        switch self {
        case .notDetermined: return "not_determined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .fullAccess: return "full_access"
        case .writeOnly: return "write_only"
        @unknown default: return "unknown"
        }
    }
}
