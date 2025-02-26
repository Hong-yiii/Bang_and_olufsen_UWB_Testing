// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var manager = NearbyManager()
    
    var body: some View {
        NavigationView {
            List(manager.airTags) { airTag in
                VStack(alignment: .leading) {
                    Text(airTag.name)
                        .font(.headline)
                    if let distance = airTag.distance {
                        Text("Distance: \(String(format: "%.2f", distance)) m")
                    }
                    if let direction = airTag.direction {
                        Text("Direction: x=\(direction.x), y=\(direction.y), z=\(direction.z)")
                    }
                }
            }
            .navigationTitle("AirTag Tracker")
        }
    }
}
