// Nactions/Presentation/TokenPickerView.swift
import SwiftUI
import NactionsKit

struct TokenPickerView: View {
    @ObservedObject var tokenManager: TokenService
    @Binding var selectedTokenID: UUID?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(tokenManager.tokens) { token in
                Button(action: {
                    selectedTokenID = token.id
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Circle()
                            .fill(token.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(token.name)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Token")
            .task {
                await tokenManager.refreshAllTokens()
            }
        }
    }
}
