//
//  Logger.swift
//  events
//
//  Created by Dominic Rodemer on 26.03.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum Logger {
    static func debug(_ message: String, function: String = #function, line: Int = #line) {
        #if DEBUG
        FileHandle.standardError.write(Data("[DEBUG] \(function):\(line) \(message)\n".utf8))
        #endif
    }

    static func error(_ error: Error?, function: String = #function, line: Int = #line) {
        #if DEBUG
        guard let error else { return }
        FileHandle.standardError.write(Data("[ERROR] \(function):\(line) \(error.localizedDescription)\n".utf8))
        #endif
    }
}
