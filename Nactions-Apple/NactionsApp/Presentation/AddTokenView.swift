// Nactions/Presentation/AddTokenView.swift
import SwiftUI
import NactionsKit

struct AddTokenView: View {
    @Binding var tokenToEdit: NotionToken?
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var apiToken: String = ""

    var body: some View {
        NavigationStack { // Updated for iOS 16+
            VStack {
                Form {
                    Section(header: Text("Token Details")) {
                        TextField("Name", text: $name)
                            .disableAutocorrection(true)
                            .textContentType(.name)

                        TextField("API Token", text: $apiToken)
                            .disableAutocorrection(true)
                            .textContentType(.none)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                }

                Spacer() // Pushes button to the bottom

                Button(action: {
                    Task {
                        if let existingToken = tokenToEdit {
                            var updatedToken = existingToken
                            updatedToken.name = name
                            updatedToken.apiToken = apiToken

                            DispatchQueue.main.async {
                                TokenService.shared.updateTokenCredentials(for: updatedToken, newApiToken: apiToken)
                                TokenService.shared.objectWillChange.send() // Force UI Refresh
                            }

                            await TokenService.shared.validateToken(updatedToken)
                        } else {
                            let newToken = NotionToken(
                                id: UUID(),
                                name: name,
                                apiToken: apiToken,
                                isConnected: false
                            )

                            DispatchQueue.main.async {
                                TokenService.shared.saveToken(name: newToken.name, apiToken: newToken.apiToken)
                                TokenService.shared.objectWillChange.send() // Force UI Refresh
                            }

                            await TokenService.shared.validateToken(newToken)
                        }
                    }
                    isPresented = false
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(name.isEmpty || apiToken.isEmpty)
            }
            .navigationTitle(tokenToEdit == nil ? "Add Token" : "Edit Token")
            .onAppear {
                if let token = tokenToEdit {
                    name = token.name
                    apiToken = token.apiToken
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)  // Fix for keyboard issues
        }
    }
}
