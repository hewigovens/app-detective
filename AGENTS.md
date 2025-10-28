# AppDetective Agent Guidelines

## CI/CD
- **GitHub Actions**: CI workflow runs on push/PR to main branch
- **Platforms**: macOS latest
- **Steps**: Checkout, build Debug, run unit tests, validate app bundle

## Build Commands
- **Build**: `xcodebuild -project AppDetective/AppDetective.xcodeproj -scheme AppDetective build`
- **Test**: `xcodebuild -project AppDetective/AppDetective.xcodeproj -scheme AppDetective test`
- **Clean**: `xcodebuild -project AppDetective/AppDetective.xcodeproj -scheme AppDetective clean`

## Code Style Guidelines

### Imports & Organization
- Group imports: Foundation first, then SwiftUI, then third-party frameworks
- One import per line, alphabetical within groups

### Naming Conventions
- **Types**: PascalCase (AppInfo, DetectService, ContentViewModel)
- **Variables/Functions**: camelCase (appResults, detectStack, scanApplications)
- **Constants**: PascalCase for global constants (Constants.AppName)

### Types & Error Handling
- Use explicit types for clarity, leverage type inference where obvious
- Use guard statements for early returns and validation
- Handle errors with do-catch blocks, prefer throwing functions over optional returns
- Use Result types for complex error scenarios

### Formatting
- 4-space indentation (Xcode default)
- Consistent spacing around operators and after commas
- Line breaks after opening braces, consistent with Swift conventions

### Architecture Patterns
- MVVM: Views observe ViewModels, ViewModels coordinate with Services
- Services for business logic (DetectService, ScanService, etc.)
- Models for data structures (AppInfo, TechStack)
- Use @MainActor for UI-related classes

### Modern Swift Features
- Prefer async/await over completion handlers
- Use property wrappers: @Published, @StateObject, @ObservedObject, @AppStorage
- Leverage SwiftUI's declarative syntax and modifiers

### Documentation
- Use /// for public API documentation
- Use // for implementation comments
- Include descriptive parameter and return value documentation