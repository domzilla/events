//
//  HelpFormatter.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum HelpFormatter {
    // MARK: - Command List

    static func formatCommandList(
        title: String,
        baseCommand: String,
        commands: [HelpCommandDTO]
    )
        -> String
    {
        var lines: [String] = []

        lines.append(title)
        lines.append("")
        lines.append("Usage: \(baseCommand) <command> [options]")
        lines.append("")
        lines.append("Commands:")

        let displayCommands = commands.map { cmd -> (name: String, desc: String) in
            let name = cmd.command
                .replacingOccurrences(of: "\(baseCommand) ", with: "")
            return (name, cmd.description)
        }
        let maxWidth = displayCommands.map(\.name.count).max() ?? 0
        let columnWidth = maxWidth + 4

        for cmd in displayCommands {
            let padding = String(repeating: " ", count: max(columnWidth - cmd.name.count, 2))
            lines.append("  \(cmd.name)\(padding)\(cmd.desc)")
        }

        lines.append("")
        lines.append("Use '\(baseCommand) <command> -h' for detailed help on a specific command.")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Command Help

    static func formatCommandHelp(_ cmd: CommandInfoDTO) -> String {
        var lines: [String] = []

        // Usage line
        var usage = cmd.command
        let hasOptions = cmd.parameters?.contains(where: { $0.name.hasPrefix("--") }) == true
        if hasOptions {
            usage += " [options]"
        }
        lines.append("Usage: \(usage)")
        lines.append("")

        // Description
        lines.append(cmd.description)
        lines.append("")

        // Parameters
        if let params = cmd.parameters, !params.isEmpty {
            let positionalParams = params.filter { $0.name.hasPrefix("<") }
            let flagParams = params.filter { $0.name.hasPrefix("--") }

            if !positionalParams.isEmpty {
                lines.append("Arguments:")
                for param in positionalParams {
                    let req = param.required ? " (required)" : ""
                    lines.append("  \(param.name)  \(param.description)\(req)")
                }
                lines.append("")
            }

            if !flagParams.isEmpty {
                lines.append("Options:")

                let formatted = flagParams.map { param -> (label: String, desc: String, required: Bool) in
                    let label: String = if param.type == "flag" {
                        param.name
                    } else {
                        "\(param.name) <\(param.type)>"
                    }
                    return (label, param.description, param.required)
                }

                let maxLabel = formatted.map(\.label.count).max() ?? 0
                let columnWidth = maxLabel + 4

                for param in formatted {
                    let padding = String(repeating: " ", count: max(columnWidth - param.label.count, 2))
                    let req = param.required ? " (required)" : ""
                    lines.append("  \(param.label)\(padding)\(param.desc)\(req)")
                }
                lines.append("")
            }
        }

        // Output
        lines.append("Output: \(cmd.output.description)")

        if let fields = cmd.output.fields, !fields.isEmpty {
            lines.append("")
            lines.append("Fields:")

            let sortedFields = fields.sorted(by: { $0.key < $1.key })
            let maxField = sortedFields.map(\.key.count).max() ?? 0
            let columnWidth = maxField + 4

            for (key, value) in sortedFields {
                let padding = String(repeating: " ", count: max(columnWidth - key.count, 2))
                lines.append("  \(key)\(padding)\(value)")
            }
        }

        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Output

    static func printAndExit(_ text: String) -> Never {
        FileHandle.standardOutput.write(Data(text.utf8))
        exit(0)
    }
}
