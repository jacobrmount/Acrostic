// Nactions/Presentation/ContentView.swift
import SwiftUI
import NactionsKit

struct ContentView: View {
    @StateObject private var tabCoordinator = TabViewCoordinator.shared
    
    var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            TokenView()
                .tabItem {
                    Label("Tokens", systemImage: "person.badge.key.fill")
                }
                .tag(AppTab.tokens)
            
            DatabaseView()
                .tabItem {
                    Label("Databases", systemImage: "server.rack")
                }
                .tag(AppTab.databases)
        }
        .onAppear {
            // Verify app group access on launch
            let groupAccessSuccessful = AppGroupConfig.verifyAppGroupAccess()
            if !groupAccessSuccessful {
                print("Failed to access app group - widgets may not work correctly")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
