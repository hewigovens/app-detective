# Contributing to App Detective

## Requirements

- Xcode 27 or later (macOS 27 SDK)
- `xcodegen`, `xcbeautify`, and `just`
- For releases: `gh`, a `notarytool` keychain profile, and the Sparkle EdDSA key in the login keychain

## Development loop

```bash
just generate                            # regenerate AppDetective.xcodeproj from project.yml
just build                               # debug build
just test                                # unit and UI tests
just run                                 # debug build + launch
just detect /Applications/Safari.app     # run the CLI on one app
```

See [AGENTS.md](AGENTS.md) for the code layout, detection rules, and conventions.

## Release workflow

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `AppDetective/project.yml`.
2. Write `releases/<version>.md`; it becomes the GitHub release notes.
3. Optionally check a local build with `just release-dry-run <version>`.
4. Run `just release <version>`: it checks the version and notes, creates a draft release, archives, exports, notarizes, zips, updates `docs/appcast.xml`, uploads the zip, and updates the Homebrew cask in `../tap` (or `$TAP_DIR`).
5. Push `main` with the appcast, publish the draft (`gh release edit <version> --draft=false --target <commit>`), and push the tap.
