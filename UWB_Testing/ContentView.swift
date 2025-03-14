import SwiftUI
import simd

/// Main entry point of the application
@main
struct MyMultiPhoneApp: App {
    @StateObject private var multiPhoneManager = MultiPhoneNIManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multiPhoneManager)
                .onAppear {
                    PermissionsManager.shared.requestPermissions { granted in
                        Logger.log("Permissions granted callback: \(granted)", from: "ContentView")
                    }
                }
        }
    }
}

/// Main view that manages the UI for tracking nearby phones
struct ContentView: View {
    @EnvironmentObject var manager: MultiPhoneNIManager
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
                Text("Multi-Phone Nearby Interaction")
                    .font(.title)
                    .bold()
                
                Text("Status: \(manager.statusMessage)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Add the direction visualization view
                if let phone = manager.connectedPhone {
                    DirectionVisualizationView(phone: phone)
                } else {
                    // Show empty placeholder square when no phone is connected
                    Rectangle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .padding()
                }
                
                if manager.connectedPhones.isEmpty {
                    Text("No connected phones detected.")
                        .font(.headline)
                        .foregroundColor(.red)
                } else {
                    List(manager.connectedPhones) { phone in
                        PhoneRow(phone: phone)
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


    
    struct PhoneRow: View {
        @ObservedObject var phone: PhoneDevice  // <-- ObservedObject ( to ensure refreshing )

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(phone.displayName)
                    .font(.headline)
                    .foregroundColor(phone.color)
                
                if let distance = phone.distance {
                    Text("Distance: \(String(format: "%.2f", distance)) m")
                } else {
                    Text("Distance: Unknown")
                }
                
                if let direction = phone.direction {
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


    func checkPermissions() {
        if !PermissionsManager.shared.isNearbyInteractionSupported {
            showAlert = true
        }
    }
}

/// A graphical representation of the phone's direction relative to the user
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

/// View displaying logs by origin
struct LogsView: View {
    @ObservedObject var logStore = Logger.sharedStore

    var body: some View {
        // Group logs by their 'origin' property.
        let grouped = Dictionary(grouping: logStore.logs, by: { $0.origin })

        VStack(alignment: .leading) {
            ForEach(grouped.keys.sorted(), id: \.self) { origin in
                // Section Header: e.g. "ContentView logs:", "MultiPhoneNIManager logs:"
                Text("\(origin) logs:")
                    .font(.headline)
                    .padding(.top, 5)

                // Display only the last 5 logs for each origin category
                let logs = grouped[origin]?.suffix(5) ?? []

                ForEach(logs, id: \.id) { logEntry in
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



/// A simple triangle shape representing an arrow
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

struct DirectionVisualizationView: View {
    @ObservedObject var phone: PhoneDevice
    
    let viewSize: CGFloat = 200 // 200x200 pt square = 7m x 7m scale
    
    var body: some View {
        ZStack {
            // Draw square boundary
            Rectangle()
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: viewSize, height: viewSize)
            
            // Draw phone position if data is available
            if let direction = phone.direction, let distance = phone.distance {
                let scale = viewSize / 10.0 // 10 meters = 200 points
                
                let xPos = CGFloat(direction.x * distance) * scale
                let zPos = CGFloat(direction.z * distance) * scale * -1 // Negative Z means "into the screen"
                
                Circle()
                    .fill(phone.color)
                    .frame(width: 20, height: 20)
                    .position(x: viewSize / 10 * 3 + xPos, y: viewSize - zPos)
                
                Text(phone.displayName)
                    .font(.caption)
                    .position(x: viewSize / 10 * 3 + xPos, y: viewSize - zPos + 15)
            }
        }
        .frame(width: viewSize, height: viewSize)
        .padding()
    }
}
