//
//  Models.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import EventKit
import Foundation

// MARK: - Common

struct DeletedDTO: Codable {
    let deleted: Bool
    let identifier: String
}

// MARK: - Status

struct StatusDTO: Codable {
    let eventsAuthorization: String
    let remindersAuthorization: String
    let availableCommands: [CommandInfoDTO]
}

struct CommandInfoDTO: Codable {
    let command: String
    let description: String
}

// MARK: - Calendar

struct CalendarDTO: Codable {
    let identifier: String
    let title: String
    let type: String
    let entityType: String
    let sourceName: String
    let color: String
    let isReadOnly: Bool

    static func from(_ calendar: EKCalendar, entityType: String) -> CalendarDTO {
        let colorHex: String
        if let cgColor = calendar.cgColor {
            let components = cgColor.components ?? [0, 0, 0]
            let r = Int((components[safe: 0] ?? 0) * 255)
            let g = Int((components[safe: 1] ?? 0) * 255)
            let b = Int((components[safe: 2] ?? 0) * 255)
            colorHex = String(format: "#%02X%02X%02X", r, g, b)
        } else {
            colorHex = "#000000"
        }

        return CalendarDTO(
            identifier: calendar.calendarIdentifier,
            title: calendar.title,
            type: calendar.type.displayString,
            entityType: entityType,
            sourceName: calendar.source?.title ?? "Unknown",
            color: colorHex,
            isReadOnly: !calendar.allowsContentModifications
        )
    }
}

// MARK: - Event

struct EventDTO: Codable {
    let identifier: String
    let title: String
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let calendar: CalendarRefDTO
    let location: String?
    let notes: String?
    let url: String?
    let availability: String
    let status: String
    let isDetached: Bool
    let hasRecurrenceRules: Bool
    let hasAlarms: Bool
    let hasAttendees: Bool
    let alarms: [AlarmDTO]?
    let attendees: [AttendeeDTO]?
    let creationDate: String?
    let lastModifiedDate: String?

    static func from(_ event: EKEvent) -> EventDTO {
        EventDTO(
            identifier: event.eventIdentifier,
            title: event.title ?? "",
            startDate: DateParsing.formatISO8601(event.startDate),
            endDate: DateParsing.formatISO8601(event.endDate),
            isAllDay: event.isAllDay,
            calendar: CalendarRefDTO.from(event.calendar),
            location: event.location,
            notes: event.notes,
            url: event.url?.absoluteString,
            availability: event.availability.displayString,
            status: event.status.displayString,
            isDetached: event.isDetached,
            hasRecurrenceRules: event.hasRecurrenceRules,
            hasAlarms: event.hasAlarms,
            hasAttendees: event.hasAttendees,
            alarms: event.alarms?.map { AlarmDTO.from($0) },
            attendees: event.attendees?.map { AttendeeDTO.from($0) },
            creationDate: event.creationDate.map { DateParsing.formatISO8601($0) },
            lastModifiedDate: event.lastModifiedDate.map { DateParsing.formatISO8601($0) }
        )
    }
}

struct CalendarRefDTO: Codable {
    let identifier: String
    let title: String

    static func from(_ calendar: EKCalendar) -> CalendarRefDTO {
        CalendarRefDTO(
            identifier: calendar.calendarIdentifier,
            title: calendar.title
        )
    }
}

struct AlarmDTO: Codable {
    let relativeOffset: Double?
    let absoluteDate: String?

    static func from(_ alarm: EKAlarm) -> AlarmDTO {
        AlarmDTO(
            relativeOffset: alarm.absoluteDate == nil ? alarm.relativeOffset : nil,
            absoluteDate: alarm.absoluteDate.map { DateParsing.formatISO8601($0) }
        )
    }
}

struct AttendeeDTO: Codable {
    let name: String?
    let status: String
    let role: String
    let type: String
    let isCurrentUser: Bool

    static func from(_ participant: EKParticipant) -> AttendeeDTO {
        AttendeeDTO(
            name: participant.name,
            status: participant.participantStatus.displayString,
            role: participant.participantRole.displayString,
            type: participant.participantType.displayString,
            isCurrentUser: participant.isCurrentUser
        )
    }
}

// MARK: - Reminder

struct ReminderDTO: Codable {
    let identifier: String
    let title: String
    let calendar: CalendarRefDTO
    let isCompleted: Bool
    let completionDate: String?
    let dueDate: String?
    let startDate: String?
    let priority: Int
    let notes: String?
    let hasAlarms: Bool
    let hasRecurrenceRules: Bool
    let creationDate: String?
    let lastModifiedDate: String?

    static func from(_ reminder: EKReminder) -> ReminderDTO {
        ReminderDTO(
            identifier: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            calendar: CalendarRefDTO.from(reminder.calendar),
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate.map { DateParsing.formatISO8601($0) },
            dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                .map { DateParsing.formatISO8601($0) },
            startDate: reminder.startDateComponents.flatMap { Calendar.current.date(from: $0) }
                .map { DateParsing.formatISO8601($0) },
            priority: reminder.priority,
            notes: reminder.notes,
            hasAlarms: reminder.hasAlarms,
            hasRecurrenceRules: reminder.hasRecurrenceRules,
            creationDate: reminder.creationDate.map { DateParsing.formatISO8601($0) },
            lastModifiedDate: reminder.lastModifiedDate.map { DateParsing.formatISO8601($0) }
        )
    }
}

// MARK: - Helpers

extension EKCalendarType {
    var displayString: String {
        switch self {
        case .local: return "local"
        case .calDAV: return "caldav"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }
}

extension EKEventAvailability {
    var displayString: String {
        switch self {
        case .notSupported: return "not_supported"
        case .busy: return "busy"
        case .free: return "free"
        case .tentative: return "tentative"
        case .unavailable: return "unavailable"
        @unknown default: return "unknown"
        }
    }
}

extension EKEventStatus {
    var displayString: String {
        switch self {
        case .none: return "none"
        case .confirmed: return "confirmed"
        case .tentative: return "tentative"
        case .canceled: return "canceled"
        @unknown default: return "unknown"
        }
    }
}

extension EKParticipantStatus {
    var displayString: String {
        switch self {
        case .unknown: return "unknown"
        case .pending: return "pending"
        case .accepted: return "accepted"
        case .declined: return "declined"
        case .tentative: return "tentative"
        case .delegated: return "delegated"
        case .completed: return "completed"
        case .inProcess: return "in_process"
        @unknown default: return "unknown"
        }
    }
}

extension EKParticipantRole {
    var displayString: String {
        switch self {
        case .unknown: return "unknown"
        case .required: return "required"
        case .optional: return "optional"
        case .chair: return "chair"
        case .nonParticipant: return "non_participant"
        @unknown default: return "unknown"
        }
    }
}

extension EKParticipantType {
    var displayString: String {
        switch self {
        case .unknown: return "unknown"
        case .person: return "person"
        case .room: return "room"
        case .resource: return "resource"
        case .group: return "group"
        @unknown default: return "unknown"
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
