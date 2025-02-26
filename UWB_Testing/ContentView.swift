import SwiftUI

@main
struct MyMultiPhoneApp: App {
    @StateObject private var multiPhoneManager = MultiPhoneNIManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multiPhoneManager)
                .onAppear {
                    PermissionsManager.shared.requestPermissions { granted in
                        Logger.log("Permissions granted? \(granted)")
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var manager: MultiPhoneNIManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Multi-Phone Nearby Interaction")
                .font(.headline)
            
            Text("Status: \(manager.statusMessage)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            List(manager.connectedPhones) { phone in
                VStack(alignment: .leading) {
                    Text(phone.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(phone.color)
                    
                    if let distance = phone.distance {
                        Text(String(format: "Distance: %.2f m", distance))
                    } else {
                        Text("Distance: unknown")
                    }
                    
                    if let direction = phone.direction {
                        Text("Direction: x=\(direction.x), y=\(direction.y), z=\(direction.z)")
                            .font(.caption)
                    } else {
                        Text("Direction: unknown")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}
