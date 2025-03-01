// Presentation/TabViewCoordinator.swift
import SwiftUI
import Combine

// Tab identifiers
enum AppTab: Int {
    case tokens = 0
    case databases = 1
}

// Coordinator for managing tab selection
class TabViewCoordinator: ObservableObject {
    static let shared = TabViewCoordinator()
    
    @Published var selectedTab: AppTab = .tokens
}
