// Acrostic.iOS/Presentation/DebugInfoView.swift
import SwiftUI
import AcrostiKit

struct DebugInfoView: View {
    @ObservedObject var tokenService = TokenService.shared
    @ObservedObject var databaseService = DatabaseService.shared
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            toggleButton
            
            if isExpanded {
                debugContentView
            }
        }
        .padding(.horizontal)
    }
    
    private var toggleButton: some View {
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
    }
    
    private var debugContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                allTokensSection
                
                Divider()
                
                activatedTokensSection
                
                Divider()
                
                databaseGroupsSection
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
    
    private var allTokensSection: some View {
        Group {
            Text("All Tokens (\(tokenService.tokens.count)):")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            ForEach(tokenService.tokens, id: \.id) { token in
                Text("• \(token.workspaceName ?? "Unknown"): connected=\(token.connectionStatus ? "✓" : "✗"), activated=\(token.isActivated ? "✓" : "✗")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var activatedTokensSection: some View {
        Group {
            Text("Activated Tokens (\(tokenService.activatedTokens.count)):")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            ForEach(tokenService.activatedTokens, id: \.id) { token in
                Text("• \(token.workspaceName ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var databaseGroupsSection: some View {
        Group {
            Text("Database Groups (\(databaseService.databaseGroups.count)):")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            ForEach(databaseService.databaseGroups) { group in
                databaseGroupView(group)
            }
        }
    }
    
    private func databaseGroupView(_ group: DatabaseGroup) -> some View {
        Group {
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
