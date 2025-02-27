//
//  ContentView.swift
//  MyMultiPhoneApp
//
//  The main SwiftUI entry for the multi-phone NI app.
//

import SwiftUI

@main
struct MyMultiPhoneApp: App {
    // Our shared manager for multi-phone NI
    @StateObject private var multiPhoneManager = MultiPhoneNIManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multiPhoneManager)
                .onAppear {
                    // Request all the needed permissions
                    PermissionsManager.shared.requestPermissions { granted in
                        Logger.log("Permissions granted callback: \(granted)")
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var manager: MultiPhoneNIManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Multi-Phone Nearby Interaction")
                    .font(.headline)
                
                Text("Status: \(manager.statusMessage)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Display the list of connected phones
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
                .listStyle(.inset)
                
                // Navigation to see the debug permission states
                NavigationLink("Check Permissions Debug") {
                    DebugPermissionsView()
                }
                .padding(.top, 20)
            }
            .padding()
            .navigationTitle("MyMultiPhoneApp")
        }
    }
}
