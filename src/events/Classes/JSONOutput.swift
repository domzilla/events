//
//  JSONOutput.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum JSONOutput {
    // MARK: - Output

    static func success(_ data: some Encodable) -> Never {
        let envelope: [String: AnyEncodable] = [
            "success": AnyEncodable(true),
            "data": AnyEncodable(data),
        ]
        self.writeJSON(envelope, to: .standardOutput)
        exit(0)
    }

    static func error(_ error: EventsError) -> Never {
        let envelope: [String: AnyEncodable] = [
            "success": AnyEncodable(false),
            "error": AnyEncodable([
                "code": AnyEncodable(error.code),
                "message": AnyEncodable(error.message),
            ]),
        ]
        self.writeJSON(envelope, to: .standardError)
        exit(error.exitCode)
    }

    // MARK: - Private

    private static func writeJSON(_ value: some Encodable, to handle: FileHandle) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(value)
            if let json = String(data: data, encoding: .utf8) {
                handle.write(Data((json + "\n").utf8))
            }
        } catch {
            let fallback = "{\"success\":false,\"error\":{\"code\":\"ENCODING_ERROR\",\"message\":\"Failed to encode output\"}}\n"
            FileHandle.standardError.write(Data(fallback.utf8))
        }
    }
}

// MARK: - AnyEncodable

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: some Encodable) {
        self._encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try self._encode(encoder)
    }
}
