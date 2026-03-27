//
//  ConfigManager.swift
//  events
//
//  Created by Dominic Rodemer on 27.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

// MARK: - Config

struct Config {
    var defaultCalendar: String?
    var defaultDuration: Int?
    var defaultAlarm: Int?
}

// MARK: - ConfigManager

enum ConfigManager {
    // MARK: - Paths

    static var configDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/events"
    }

    static var configFile: String {
        "\(self.configDirectory)/config"
    }

    // MARK: - Load

    static func load() -> Config {
        var config = Config()

        guard let contents = try? String(contentsOfFile: self.configFile, encoding: .utf8) else {
            Logger.debug("No config file found at \(self.configFile)")
            return config
        }

        Logger.debug("Loading config from \(self.configFile)")

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Split on first '='
            guard let equalsIndex = trimmed.firstIndex(of: "=") else {
                Logger.debug("Skipping malformed config line: \(trimmed)")
                continue
            }

            let key = trimmed[trimmed.startIndex..<equalsIndex]
                .trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: equalsIndex)...]
                .trimmingCharacters(in: .whitespaces)

            if value.isEmpty {
                continue
            }

            switch key {
            case "default_calendar":
                config.defaultCalendar = value
                Logger.debug("Config: default_calendar = \(value)")
            case "default_duration":
                if let minutes = Int(value) {
                    config.defaultDuration = minutes
                    Logger.debug("Config: default_duration = \(minutes)")
                } else {
                    Logger.debug("Config: invalid default_duration value: \(value)")
                }
            case "default_alarm":
                if let minutes = Int(value) {
                    config.defaultAlarm = minutes
                    Logger.debug("Config: default_alarm = \(minutes)")
                } else {
                    Logger.debug("Config: invalid default_alarm value: \(value)")
                }
            default:
                Logger.debug("Config: unknown key '\(key)', skipping")
            }
        }

        return config
    }

    // MARK: - Create Default Config

    static func createDefaultConfig() throws {
        let path = self.configFile

        if FileManager.default.fileExists(atPath: path) {
            throw EventsError.configAlreadyExists(path: path)
        }

        // Create directory if needed
        let directory = self.configDirectory
        if !FileManager.default.fileExists(atPath: directory) {
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
        }

        let template = """
        # events CLI configuration
        # Location: ~/.config/events/config
        #
        # Values set here are used as defaults and can always be
        # overridden by command-line flags.

        # Default calendar name for new events.
        # Use the exact calendar name as shown in Calendar.app.
        # Examples: Work, Personal, Büro, Termine Dominic
        # default_calendar =

        # Default event duration in minutes.
        # Used to calculate end date when --end is omitted.
        # Built-in default: 60
        # default_duration = 60

        # Default alarm in minutes before event start.
        # Added to every new event unless overridden with --alarm.
        # default_alarm =
        """

        try template.write(toFile: path, atomically: true, encoding: .utf8)
        Logger.debug("Created config file at \(path)")
    }
}
