// Nactions/Presentation/DatabaseView.swift
import SwiftUI
import NactionsKit

struct DatabaseView: View {
    @ObservedObject var databaseService = DatabaseService.shared
    @ObservedObject var tokenService = TokenService.shared
    @State private var showDebugInfo = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if databaseService.isLoading {
                    ProgressView("Loading databases...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if tokenService.activatedTokens.isEmpty {
                    noActivatedTokensView
                } else if databaseService.databaseGroups.isEmpty {
                    emptyStateView
                } else {
                    databaseListView
                }
            }
            .navigationTitle("Databases")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await databaseService.refreshDatabases()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showDebugInfo.toggle()
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .alert(item: Binding(
                get: { databaseService.errorMessage.map { ErrorWrapper(error: $0) } },
                set: { _ in databaseService.errorMessage = nil }
            )) { errorWrapper in
                Alert(
                    title: Text("Error"),
                    message: Text(errorWrapper.error),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                VStack {
                    Spacer()
                    if showDebugInfo {
                        DebugInfoView()
                            .transition(.move(edge: .bottom))
                    }
                }
            )
        }
        .task {
            // Initial load of databases
            if !databaseService.isLoading && databaseService.databaseGroups.isEmpty {
                await databaseService.refreshDatabases()
            }
        }
    }
    
    // View when no tokens are activated
    private var noActivatedTokensView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("No active tokens")
                .font(.headline)
            
            Text("Please activate one or more tokens in the Tokens tab to view databases.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                // Use TabView selection to switch tabs programmatically
                TabViewCoordinator.shared.selectedTab = .tokens
            }) {
                Text("Go to Tokens")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
    }
    
    // View when no databases found
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No databases found")
                .font(.headline)
            
            Text("No databases found for your activated tokens. Try refreshing or check your Notion workspace.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await databaseService.refreshDatabases()
                }
            }) {
                Text("Refresh")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
    }
    
    private func convertToViewModel(_ internal: DatabaseViewModelInternal) -> DatabaseViewModel {
        return DatabaseViewModel(
            id: `internal`.id,
            title: `internal`.title,
            tokenID: `internal`.tokenID,
            tokenName: `internal`.tokenName,
            isSelected: `internal`.isSelected,
            lastUpdated: `internal`.lastUpdated
        )
    }
    
    // Main database list
    private var databaseListView: some View {
        List {
            ForEach(databaseService.databaseGroups) { group in
                Section(header: Text(group.tokenName)) {
                    ForEach(group.databases) { database in
                        DatabaseRowView(database: convertToViewModel(database)) {
                            // Toggle selection when tapped
                            databaseService.toggleDatabaseSelection(
                                databaseID: database.id,
                                tokenID: database.tokenID
                            )
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

// Error wrapper to make the alert work with optionals
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
}

// Database row component
struct DatabaseRowView: View {
    let database: DatabaseViewModel
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: database.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                
                VStack(alignment: .leading) {
                    Text(database.title)
                        .font(.headline)
                    
                    Text("Last updated: \(database.lastUpdated, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
