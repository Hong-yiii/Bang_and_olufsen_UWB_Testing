import SwiftUI

/// A single log entry
struct AppLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let origin: String
    let message: String
}

/// A store that keeps track of all log entries in an array.
/// Marked as an ObservableObject so SwiftUI can observe it.
class LogStore: ObservableObject {
    @Published var logs: [AppLog] = []
    
    func add(_ entry: AppLog) {
        logs.append(entry)
    }
}

/// A static logger that has a shared LogStore
/// and a function to append new logs from anywhere in the app.
struct Logger {
    /// The shared repository for all log entries
    static var sharedStore = LogStore()
    
    /// Logs a new message.
    /// `origin` defaults to "General" if you don't specify anything.
    static func log(_ message: String, from origin: String = "General") {
        print("[\(origin)] \(message)")  // Always print to console
        DispatchQueue.main.async {
            let entry = AppLog(origin: origin, message: message)
            sharedStore.add(entry)
        }
    }
}
