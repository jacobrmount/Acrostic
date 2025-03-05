// Acrostic.iOS/Presentation/FileSelectorView.swift
import SwiftUI
import AcrostiKit

struct FileSelectorView: View {
    @ObservedObject var fileService = FileService.shared
    @ObservedObject var tokenService = TokenService.shared
    @State private var showDebugInfo = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if fileService.isLoading {
                    ProgressView("Loading files...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if tokenService.activatedTokens.isEmpty {
                    noActivatedTokensView
                } else if fileService.fileGroups.isEmpty {
                    emptyStateView
                } else {
                    fileListView
                }
            }
            .navigationTitle("File Selector")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await fileService.loadFileMetadata()
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
            .alert(item: Binding<ErrorWrapper?>(
                get: { fileService.errorMessage.map { ErrorWrapper(error: $0) } },
                set: { _ in }
            )) { errorWrapper in
                Alert(
                    title: Text("Error"),
                    message: Text(errorWrapper.error),
                    dismissButton: .default(Text("OK")) {
                        fileService.errorMessage = nil
                    }
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
            if !fileService.isLoading && fileService.fileGroups.isEmpty {
                await fileService.loadFileMetadata()
            }
        }
    }
    
    // View when no tokens are activated - now moved inside the struct
    private var noActivatedTokensView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("No active tokens")
                .font(.headline)
            
            Text("Please activate one or more tokens in the Tokens tab to view files.")
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
    
    // View when no files found - now moved inside the struct
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No files found")
                .font(.headline)
            
            Text("No files found for your activated tokens. Try refreshing or check your Notion workspace.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await fileService.loadFileMetadata()
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
    
    // Main file list
    private var fileListView: some View {
        List {
            ForEach(fileService.fileGroups) { group in
                Section(header: Text(group.tokenName)) {
                    ForEach(group.files) { file in
                        FileRowView(file: file) {
                            fileService.toggleFileSelection(
                                fileID: file.id,
                                tokenID: file.tokenID
                            )
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct FileRowView: View {
    let file: FileMetadata
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                
                VStack(alignment: .leading) {
                    Text(file.title)
                        .font(.headline)
                    
                    Text(file.type == .database ? "Database" : "Page")
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

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
}
