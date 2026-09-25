# AppDetective Agent Guidelines

## Project Layout
- `AppDetective/project.yml`: XcodeGen spec. The `.xcodeproj` is generated and git-ignored; edit `project.yml`, never the project file.
- `AppDetective/Packages/DetectiveCore`: detection logic (`DetectService`, `TechStack`, `BundleMetrics`), shared by the app and the CLI.
- `AppDetective/AppDetective`: SwiftUI app. `AppAnalyzer` runs detection plus icon/size loading per app, and `DiskCacheService` keeps the results in `~/Library/Caches`, reused while the app's Info.plist date and `DetectService.version` are unchanged.
- `AppDetective/CLI`: the `appdetective` command-line tool, embedded in the app bundle. Its module is `AppDetectiveCLI` so it doesn't collide with the app's `AppDetective` module on case-insensitive disks.
- `AppDetective/AppDetectiveTests`: Swift Testing unit tests, hosted by the app. Use `@testable import AppDetective` / `DetectiveCore`, and `FakeApp` from `TestSupport.swift` for bundle fixtures. The CLI tests run the copy embedded in the host app.
- `AppDetective/AppDetectiveUITests`: XCTest UI tests.

## CI/CD
- **GitHub Actions**: `.github/workflows/ci.yml` runs `just build` and `just test` on branch pushes and PRs to main
- **Platform**: the `xcode-27` runner (macOS 27 with Xcode 27, a GitHub preview image; there is no `macos-27` label yet); the app and CLI deploy to macOS 14.6

## Release Packaging
- Package release apps with `scripts/package-release-zip.sh`, which uses `ditto --norsrc` so AppleDouble metadata is not written into signed app bundles.
- Verify final notarized archives with `scripts/verify-release-archive.sh <zip> notarized`; it extracts the archive and runs `codesign`, `stapler validate`, and `spctl -av` on the extracted app.

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
- Detection lives in `Packages/DetectiveCore/Sources/DetectiveCore/Detection/`. Each stack has a `StackSignature` in `StackSignatures.swift`: a list of rules, each an `Evidence` (framework, resource, plug-in, file, linked library, embedded string) with a `Confidence`.
- **Confidence**: `.strong` identifies the stack alone (its runtime is bundled or linked); `.weak` is circumstantial. A stack is reported at one strong or two weak matches; below that it appears in `possibleStacks`. Don't mark substring or string matches strong unless the text is unique to the stack.
- **Adding a stack**: add the flag, `allStacks` entry, and name in `TechStack.swift`; its color in `TechStack+Color.swift`; its signature in `StackSignatures.swift`; and a fake-bundle test in `DetectServiceTests.swift`.
- AppKit and UIKit are reported only when nothing more specific matched, together with the language (`.swift` when the Swift runtime is linked, else `.objectiveC`); `TechStack.languages` never counts as a specific stack.
- Embedded-string rules run `strings` over the executable, so they are evaluated only when no stack beyond AppKit/UIKit was found (a SwiftUI or cross-platform match skips them). Prefer file or linked-library evidence; note the app's own binary contains every catalog string.
- Catalog edits change `DetectService.version` automatically, which invalidates saved results. Bump `engineVersion` when changing detection logic outside the catalog (thresholds, resolution).
- Use `appdetective --explain <app>` to see which rules matched. Before and after a detection change, run the CLI over `/Applications` and diff the results; only intended apps should change.

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
- View models are `@MainActor @Observable`; views take them as plain `let` properties and use `@Bindable` for bindings
- The project builds in Swift 6 language mode; keep it free of concurrency warnings
- Keep a single source of truth: derived state (filtered lists, counts) is computed once when inputs change, not in view bodies
- Share preview data via `AppInfo.samples` instead of duplicating fixtures per view

### Modern Swift Features
- Prefer async/await over completion handlers
- Use Observation (`@Observable`, `@State`, `@Bindable`), not `ObservableObject`/`@Published`
- Leverage SwiftUI's declarative syntax and modifiers

### Documentation & Comments
- Keep comments rare: names and types should carry the meaning. No doc comments that restate a declaration's name or signature, and no `// MARK:` in small files
- Use a one-line // only to explain *why* (constraints, workarounds, non-obvious behavior); never restate what the code does
- Don't leave commented-out code, placeholder actions, or unused types behind

### Logging
- Use `os.Logger` (`Logger.app`, `Logger.cache`) in the app, never `print`; `print` is only for CLI output
