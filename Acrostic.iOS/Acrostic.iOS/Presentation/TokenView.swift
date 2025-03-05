// Acrostic.iOS/Presentation/TokenView.swift
import SwiftUI
import LocalAuthentication
import AcrostiKit

struct TokenView: View {
    @ObservedObject var tokenManager = TokenService.shared
    @State private var showingAddToken = false
    @State private var tokenToEdit: TokenEntity? = nil
    @State private var tokenToDelete: TokenEntity? = nil
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var showingImportFailure = false

    var body: some View {
        NavigationView {
            tokenListContent
                .navigationTitle("Tokens")
                .navigationBarItems(
                    trailing: HStack(spacing: 16) {
                        Button("Import") {
                            importTokens()
                        }
                        
                        Text("|")
                            .foregroundColor(.gray)
                        
                        Button("Export") {
                            exportTokens()
                        }
                    }
                )
                .sheet(isPresented: $showingAddToken) {
                    AddTokenView(
                        tokenToEdit: Binding(
                            get: { tokenToEdit },
                            set: { tokenToEdit = $0 }
                        ),
                        isPresented: $showingAddToken
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .alert("Export Successful", isPresented: $showingExportSuccess) {
                    Button("OK", role: .cancel) {}
                }
                .alert("Import Successful", isPresented: $showingImportSuccess) {
                    Button("OK", role: .cancel) {
                        tokenManager.loadTokens()
                    }
                }
                .alert("Import Failed", isPresented: $showingImportFailure) {
                    Button("OK", role: .cancel) {}
                }
                .onAppear {
                    tokenManager.loadTokens()
                }
        }
    }
    
    private var tokenListContent: some View {
        ZStack {
            VStack {
                if tokenManager.tokens.isEmpty {
                    Text("No tokens available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(tokenManager.tokens, id: \.id) { token in
                            HStack {
                                Button(action: {
                                    tokenManager.toggleTokenActivation(token: token)
                                }) {
                                    Image(systemName: token.isActivated ? "checkmark.square.fill" : "square")
                                        .foregroundColor(token.connectionStatus ? .blue : .gray)
                                        .imageScale(.large)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!token.connectionStatus)
                                .help(token.connectionStatus ? "Click to toggle activation" : "Connection required to activate")
                                
                                Button(action: {
                                    tokenToEdit = token
                                    showingAddToken = true
                                }) {
                                    Text(token.workspaceName ?? "Unknown")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(token.connectionStatus ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    tokenToDelete = token
                                    showingDeleteConfirmation = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .padding()
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        tokenToEdit = nil
                        showingAddToken = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .shadow(radius: 5)
                            .padding(.trailing, 25)
                            .padding(.bottom, 25)
                    }
                }
            }
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Token"),
                message: Text("This action cannot be undone. Are you sure?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let token = tokenToDelete {
                        tokenManager.deleteToken(token)
                    }
                    tokenToDelete = nil
                },
                secondaryButton: .cancel {
                    tokenToDelete = nil
                }
            )
        }
    }
    
    private func exportTokens() {
        TokenBackupManager.exportTokens { success in
            if success {
                showingExportSuccess = true
            }
        }
    }

    private func importTokens() {
        TokenBackupManager.importTokens { success in
            if success {
                DispatchQueue.main.async {
                    tokenManager.loadTokens()
                }
                showingImportSuccess = true
            } else {
                showingImportFailure = true
            }
        }
    }
}

struct TokenView_Previews: PreviewProvider {
    static var previews: some View {
        TokenView(tokenManager: TokenService.shared.makePreviewManager())
    }
}
