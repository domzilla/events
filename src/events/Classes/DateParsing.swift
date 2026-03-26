//
//  DateParsing.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum DateParsing {
    // MARK: - Formatters

    private static let iso8601Full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let outputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Parsing

    static func parseISO8601(_ string: String) throws -> Date {
        if let date = self.iso8601Full.date(from: string) {
            return date
        }
        if let date = self.iso8601WithFractional.date(from: string) {
            return date
        }
        if let date = self.dateOnly.date(from: string) {
            return date
        }
        throw EventsError.invalidArgument(name: "date", value: string)
    }

    static func formatISO8601(_ date: Date) -> String {
        self.outputFormatter.string(from: date)
    }

    // MARK: - Date Components

    static func dateComponents(from date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    // MARK: - Helpers

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: self.startOfDay(date, calendar: calendar)) ?? date
    }
}
