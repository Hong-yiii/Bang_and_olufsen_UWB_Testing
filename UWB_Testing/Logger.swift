import Foundation

struct Logger {
    static func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("[\(timestamp)] \(message)")
    }
}
