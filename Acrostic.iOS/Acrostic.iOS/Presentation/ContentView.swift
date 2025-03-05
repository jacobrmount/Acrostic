// Acrostic.iOS/Presentation/ContentView.swift
import SwiftUI
import AcrostiKit

struct ContentView: View {
    @StateObject private var tabCoordinator = TabViewCoordinator.shared
    
    var body: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            TokenView()
                .tabItem {
                    Label("Tokens", systemImage: "person.badge.key.fill")
                }
                .tag(AppTab.tokens)
            
            FileSelectorView()
                .tabItem {
                    Label("File Select", systemImage: "folder")
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
