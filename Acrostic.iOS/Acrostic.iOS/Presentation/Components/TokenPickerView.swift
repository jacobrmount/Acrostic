// Acrostic.iOS/Presentation/TokenPickerView.swift
import SwiftUI
import AcrostiKit

struct TokenPickerView: View {
    @ObservedObject var tokenManager: TokenService
    @Binding var selectedTokenID: UUID?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(tokenManager.tokens, id: \.objectID) { token in
                Button(action: {
                    selectedTokenID = token.value(forKey: "id") as? UUID
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Circle()
                            .fill((token.value(forKey: "isActivated") as? Bool) == true ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(token.value(forKey: "workspaceName") as? String ?? "Unknown")
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
