//
//  Errors.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum EventsError: Error {
    case authorizationDenied(entity: String)
    case notFound(type: String, identifier: String)
    case validationError(message: String)
    case calendarReadOnly(identifier: String)
    case eventKitError(underlying: Error)
    case missingRequiredArgument(name: String)
    case invalidArgument(name: String, value: String)
    case unknownCommand(command: String)

    var code: String {
        switch self {
        case .authorizationDenied:
            "AUTHORIZATION_DENIED"
        case .notFound:
            "NOT_FOUND"
        case .validationError:
            "VALIDATION_ERROR"
        case .calendarReadOnly:
            "CALENDAR_READ_ONLY"
        case .eventKitError:
            "EVENTKIT_ERROR"
        case .missingRequiredArgument:
            "MISSING_REQUIRED_ARGUMENT"
        case .invalidArgument:
            "INVALID_ARGUMENT"
        case .unknownCommand:
            "UNKNOWN_COMMAND"
        }
    }

    var message: String {
        switch self {
        case let .authorizationDenied(entity):
            "Access to \(entity) was denied. Grant permission in System Settings > Privacy & Security."
        case let .notFound(type, identifier):
            "\(type) not found with identifier: \(identifier)"
        case let .validationError(message):
            message
        case let .calendarReadOnly(identifier):
            "Calendar is read-only: \(identifier)"
        case let .eventKitError(underlying):
            "EventKit error: \(underlying.localizedDescription)"
        case let .missingRequiredArgument(name):
            "Missing required argument: \(name)"
        case let .invalidArgument(name, value):
            "Invalid value '\(value)' for argument: \(name)"
        case let .unknownCommand(command):
            "Unknown command: \(command)"
        }
    }

    var exitCode: Int32 {
        switch self {
        case .authorizationDenied:
            2
        case .notFound:
            3
        case .validationError, .missingRequiredArgument, .invalidArgument, .unknownCommand:
            4
        case .calendarReadOnly:
            5
        case .eventKitError:
            1
        }
    }
}
