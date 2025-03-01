// Nactions/Presentation/DebugInfoView.swift
import SwiftUI
import NactionsKit

struct DebugInfoView: View {
    @ObservedObject var tokenService = TokenService.shared
    @ObservedObject var databaseService = DatabaseService.shared
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack {
                    Text("Debug Info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Group {
                            Text("All Tokens (\(tokenService.tokens.count)):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                            
                            ForEach(tokenService.tokens) { token in
                                Text("• \(token.name): connected=\(token.isConnected ? "✓" : "✗"), activated=\(token.isActivated ? "✓" : "✗")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Activated Tokens (\(tokenService.activatedTokens.count)):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                            
                            ForEach(tokenService.activatedTokens) { token in
                                Text("• \(token.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Group {
                            Text("Database Groups (\(databaseService.databaseGroups.count)):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                            
                            ForEach(databaseService.databaseGroups) { group in
                                Text("• \(group.tokenName): \(group.databases.count) databases")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(group.databases) { db in
                                    Text("  - \(db.title): selected=\(db.isSelected ? "✓" : "✗")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                .frame(height: 200)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }
}
