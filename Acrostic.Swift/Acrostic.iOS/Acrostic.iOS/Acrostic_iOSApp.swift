//
//  Acrostic_iOSApp.swift
//  Acrostic.iOS
//
//  Created by Jacob Mount on 3/4/25.
//

import SwiftUI

@main
struct Acrostic_iOSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
