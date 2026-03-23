# Contributing to App Detective

## Requirements

- Xcode 16.0 or later
- `xcodegen`
- `just`

## Development loop

```bash
just generate    # regenerate AppDetective.xcodeproj from project.yml
just run         # debug build + launch
```

## Release workflow

```bash
just archive <version>   # Release archive via Xcode
just export <version>    # pull .app into build/export
just zip <version>       # create zip in build/dist
just release <version>   # full pipeline in sequence
```
