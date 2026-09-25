# AppDetective Agent Guidelines

## Project Layout
- `AppDetective/project.yml`: XcodeGen spec. The `.xcodeproj` is generated and git-ignored; edit `project.yml`, never the project file.
- `AppDetective/Packages/DetectiveCore`: detection logic (`DetectService`, `TechStack`, `BundleMetrics`), shared by the app and the CLI.
- `AppDetective/AppDetective`: SwiftUI app (views, view models, app-only services such as the metadata cache and CLI installer).
- `AppDetective/CLI`: the `appdetective` command-line tool, embedded in the app bundle.
- `AppDetective/AppDetectiveTests`: Swift Testing unit tests; `AppDetectiveUITests`: XCTest UI tests.

## CI/CD
- **GitHub Actions**: `.github/workflows/ci.yml` runs `just build` and `just test` on branch pushes and PRs to main
- **Platform**: macOS 26 runner; the app and CLI deploy to macOS 14.6

## Jujutsu Workflow
- **Tooling**: Use Jujutsu (`jj`) for local version control. The Git checkout may appear as detached `HEAD`; this is expected.
- **Task Changes**: Always start from a fresh `jj` change for each task or feature before editing. Use a bookmark when a named branch is needed for sharing or pushing.
- **Descriptions**: Always propose a draft change description/commit message and ask for user confirmation before finalizing it. Don't hard-wrap description lines at 72/80 columns.
- **Tools**: Use `jj` (and the JayJay app via `jayjay` for reviewing diffs), not `git`, for version control.
- **Pushing**: Never push bookmarks or changes to the remote repository without explicit user request.

## Build Commands
Use the `justfile` recipes; they regenerate the Xcode project first.
- **Build**: `just build`
- **Test** (unit + UI): `just test`
- **Run the app**: `just run`
- **Run the CLI on one app**: `just detect /Applications/Safari.app`
- **Regenerate the project only**: `just generate`
- Don't run `swift build` inside `Packages/DetectiveCore`; it leaves `.build/` and `Package.resolved` in the working copy, which jj snapshots.

## Detection Changes
- Detection rules are data tables in `DetectService.swift` (framework names, linked-library markers, embedded strings). Add a signature there rather than new branching logic.
- Before and after a detection change, run the CLI over `/Applications` and diff the results; only intended apps should change.
- Cover new rules with a fake-bundle test in `DetectServiceTests.swift`.

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
- Use @MainActor for all view models
- Keep a single source of truth: derived state (filtered lists, counts) is computed once when inputs change, not in view bodies
- Share preview data via `AppInfo.samples` instead of duplicating fixtures per view

### Modern Swift Features
- Prefer async/await over completion handlers
- Use property wrappers: @Published, @StateObject, @ObservedObject, @AppStorage
- Leverage SwiftUI's declarative syntax and modifiers

### Documentation & Comments
- Use /// for public API documentation, with parameter and return descriptions where they aren't obvious
- Use // only to explain *why* (constraints, workarounds, non-obvious behavior); don't restate what the code does
- Don't leave commented-out code, placeholder actions, or unused types behind

### Logging
- Use `os.Logger` (`Logger.app`, `Logger.cache`) in the app, never `print`; `print` is only for CLI output
