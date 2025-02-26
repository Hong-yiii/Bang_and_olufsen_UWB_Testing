// Logger.swift
import Foundation

struct Logger {
    static func log(_ message: String) {
        let timestamp = Date().formatted()
        print("[\(timestamp)]: \(message)")
    }
}
