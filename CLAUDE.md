# Acrostic iOS Project Guidelines

## Build/Test Commands
- Build app: Open Xcode, select scheme, ⌘R
- Run all tests: ⌘U in Xcode
- Run single test: Click test diamond or use Test navigator
- Debug in Xcode with breakpoints and console logging

## Code Style & Organization
- **Imports**: Foundation first, then UIKit/SwiftUI, then others
- **Naming**: 
  - Classes/structs: `PascalCase` (e.g., `TokenEntity`)
  - Variables/properties: `camelCase` (e.g., `workspaceID`)
  - API models use `Notion` prefix, entities use `Entity` suffix
- **Structure**: Use `// MARK: - Section Name` for code organization
- **Types**: Explicit optionality (`String?` vs `String`)
- **Error Handling**: Custom error enums implementing `Error` and `LocalizedError`

## Project Architecture
- **AcrostiKit**: Core framework with API, Business Logic, Data Management
- **Acrostic.iOS**: Main app with SwiftUI views
- **AcrosticWidgets**: Widget extensions
- **Testing**: Use `CoreDataTestHelper` for in-memory Core Data tests
- **Patterns**: MVVM architecture with dependency injection

## CoreData Practices
- Use managed object context with view context for UI
- Controllers for different entity types (e.g., `TokenDataController`)
- Entity extensions for helper methods and computed properties