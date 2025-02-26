//
//  Logger.swift
//  MyMultiPhoneApp
//
//  Logs messages with timestamps in console.
//

import Foundation

/// A basic utility for printing logs with timestamps.
struct Logger {
    /// Prints a log message with a standard date-time stamp.
    static func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("[\(timestamp)] \(message)")
    }
}
