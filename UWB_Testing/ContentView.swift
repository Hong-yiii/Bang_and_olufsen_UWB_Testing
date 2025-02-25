import SwiftUI

struct ContentView: View {
    @StateObject private var proximityManager = ProximityManager()
    
    var body: some View {
        VStack {
            Text("Proximity Audio Switcher")
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                proximityManager.startTracking()
            }) {
                Text(proximityManager.isTracking ? "Tracking..." : "Start Tracking")
            }
            .padding()
            .disabled(proximityManager.isTracking)
            
            if let distance = proximityManager.distanceToAirtag {
                Text("Distance to AirTag: \(String(format: "%.2f", distance)) m")
            }
            
            if let distance = proximityManager.distanceToHomepod {
                Text("Distance to HomePod: \(String(format: "%.2f", distance)) m")
            }
        }
        .padding()
    }
}

