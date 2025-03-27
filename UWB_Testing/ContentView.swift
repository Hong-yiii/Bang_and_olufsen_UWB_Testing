import SwiftUI
import simd

@main
struct UWBTestingApp: App {
    @StateObject private var accessoryManager = AccessoryNIManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accessoryManager)
                .onAppear {
                    PermissionsManager.shared.requestPermissions { granted in
                        Logger.log("Permissions granted callback: \(granted)", from: "App Entry")
                    }
                }
        }
    }
}


/// Main view that manages the UI for tracking nearby accessories
struct ContentView: View {
    @EnvironmentObject var manager: AccessoryNIManager
    @State private var showAlert = false

    var body: some View {
        TabView {
            mainTrackerView
                .tabItem {
                    Label("Tracker", systemImage: "location.circle.fill")
                }

            DebugPermissionsView()
                .tabItem {
                    Label("Permissions", systemImage: "gear")
                }
        }
        .onAppear {
            checkPermissions()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Permissions Required"),
                  message: Text("Please enable location, Bluetooth, and network permissions in Settings."),
                  dismissButton: .default(Text("OK")))
        }
    }

    var mainTrackerView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Accessory Tracker")
                    .font(.title)
                    .bold()

                Text("Total Accessories: \(manager.accessories.count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if manager.accessories.isEmpty {
                    Text("No accessories detected.")
                        .font(.headline)
                        .foregroundColor(.red)
                } else {
                    List {
                        ForEach(Array(manager.accessories.values), id: \ .id) { accessory in
                            AccessoryRow(accessory: accessory)
                        }
                    }
                    .listStyle(.grouped)
                }

                VStack(alignment: .leading) {
                    Text("Logs:")
                        .font(.headline)
                        .padding(.top, 10)

                    ScrollView {
                        LogsView()
                    }
                    .frame(height: 150)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Tracker")
        }
    }

    func checkPermissions() {
        if !PermissionsManager.shared.isNearbyInteractionSupported {
            showAlert = true
        }
    }
}

/// View displaying logs by origin
struct LogsView: View {
    @ObservedObject var logStore = Logger.sharedStore

    var body: some View {
        let grouped = Dictionary(grouping: logStore.logs, by: { $0.origin })

        VStack(alignment: .leading) {
            ForEach(grouped.keys.sorted(), id: \ .self) { origin in
                Text("\(origin) logs:")
                    .font(.headline)
                    .padding(.top, 5)

                let logs = grouped[origin]?.suffix(5) ?? []

                ForEach(logs, id: \ .id) { logEntry in
                    Text(logEntry.message)
                        .font(.caption)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(5)
                }
            }
        }
    }
}

/// A graphical representation of the accessory's direction relative to the user
struct DirectionIndicator: View {
    let direction: simd_float3

    var body: some View {
        VStack {
            Text("Direction")
                .font(.caption)

            ZStack {
                Circle()
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(width: 50, height: 50)

                ArrowShape()
                    .rotationEffect(Angle(radians: atan2(Double(direction.y), Double(direction.x))))
                    .frame(width: 20, height: 20)
                    .foregroundColor(.blue)
            }
        }
    }
}

/// Simple triangle shape for direction arrow
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Displays a single accessory device's info
struct AccessoryRow: View {
    @ObservedObject var accessory: AccessoryDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(accessory.accessoryName)
                .font(.headline)

            if let distance = accessory.distance {
                Text("Distance: \(String(format: "%.2f", distance)) m")
            } else {
                Text("Distance: Unknown")
            }

            if let direction = accessory.direction {
                DirectionIndicator(direction: direction)
            } else {
                Text("Direction: Unknown")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(radius: 2))
    }
}

// Preview for development
#Preview {
    ContentView().environmentObject(AccessoryNIManager())
}
