import SwiftUI
import simd

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
            
            // Display distances
            if let distance = proximityManager.distanceToAirtag {
                Text("Distance to AirTag: \(String(format: "%.2f", distance)) m")
            }
            
            if let distance = proximityManager.distanceToHomepod {
                Text("Distance to HomePod: \(String(format: "%.2f", distance)) m")
            }
            
            // 2D Direction Visualization
            ZStack {
                DirectionView(
                    direction: proximityManager.airtagDirection,
                    label: "AirTag",
                    color: .blue
                )
                
                DirectionView(
                    direction: proximityManager.homepodDirection,
                    label: "HomePod",
                    color: .green
                )
            }
            .frame(width: 200, height: 200)
            .padding()
        }
        .padding()
        .onAppear {
        // Request permissions when the view appears
            PermissionsManager.shared.requestLocalNetworkPermission()
            PermissionsManager.shared.requestBluetoothPermission()
            PermissionsManager.shared.requestNearbyInteractionPermission()
            PermissionsManager.shared.requestLocationPermission()
        }
    }
}

struct DirectionView: View {
    var direction: SIMD3<Float>?
    var label: String
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            if let dir = direction {
                let x = CGFloat(dir.x) * geometry.size.width / 2
                let y = CGFloat(dir.y) * geometry.size.height / 2
                
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .position(
                        x: geometry.size.width / 2 + x,
                        y: geometry.size.height / 2 - y
                    )
                
                Text(label)
                    .position(
                        x: geometry.size.width / 2 + x,
                        y: geometry.size.height / 2 - y - 15
                    )
            }
        }
    }
}
