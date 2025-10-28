set shell := ["bash", "-lc"]
set export

PROJECT := "AppDetective/AppDetective.xcodeproj"
SCHEME := "AppDetective"
ARCHIVE_DIR := "build/archive"
EXPORT_DIR := "build/export"
DIST_DIR := "build/dist"
UPDATE_DIR := "update"
DOWNLOAD_BASE ?= "https://hewig.dev/appdetecive"
MIN_SYSTEM_VERSION ?= "13.0"

alias release := release

# Archive the app for distribution.
archive version:
    set -euxo pipefail
    mkdir -p {{ARCHIVE_DIR}}
    xcodebuild \
      -project {{PROJECT}} \
      -scheme {{SCHEME}} \
      -configuration Release \
      -archivePath {{ARCHIVE_DIR}}/AppDetective-{{version}}.xcarchive \
      archive

# Export the .app bundle from the archive into build/export.
export version:
    set -euxo pipefail
    ARCHIVE_PATH={{ARCHIVE_DIR}}/AppDetective-{{version}}.xcarchive
    DEST_DIR={{EXPORT_DIR}}/AppDetective-{{version}}
    if [ ! -d "$ARCHIVE_PATH" ]; then
      echo "Archive not found at $ARCHIVE_PATH" >&2
      exit 1
    fi
    rm -rf "$DEST_DIR"
    mkdir -p "$DEST_DIR"
    rsync -a "$ARCHIVE_PATH/Products/Applications/AppDetective.app" "$DEST_DIR/"

# Create a Sparkle-friendly zip from the exported .app bundle.
zip version:
    set -euxo pipefail
    SOURCE_APP={{EXPORT_DIR}}/AppDetective-{{version}}/AppDetective.app
    OUTPUT_ZIP={{DIST_DIR}}/AppDetective-{{version}}.zip
    if [ ! -d "$SOURCE_APP" ]; then
      echo "App bundle not found at $SOURCE_APP" >&2
      exit 1
    fi
    mkdir -p {{DIST_DIR}}
    ditto -c -k --sequesterRsrc --keepParent "$SOURCE_APP" "$OUTPUT_ZIP"

# Generate or update the Sparkle appcast entry for the provided version.
generate-appcast version notes="":
    set -euxo pipefail
    ZIP_PATH={{DIST_DIR}}/AppDetective-{{version}}.zip
    if [ ! -f "$ZIP_PATH" ]; then
      echo "Zip not found at $ZIP_PATH" >&2
      exit 1
    fi
    args=(
      --appcast {{UPDATE_DIR}}/appcast.xml
      --zip "$ZIP_PATH"
      --version {{version}}
      --short-version "${SHORT_VERSION:-{{version}}}"
      --download-url "${DOWNLOAD_BASE}/AppDetective-{{version}}.zip"
      --min-system-version "${MIN_SYSTEM_VERSION}"
    )
    if [ -n "{{notes}}" ]; then
      args+=(--notes-file "{{notes}}")
    elif [ -f {{UPDATE_DIR}}/notes/{{version}}.md ]; then
      args+=(--notes-file "{{UPDATE_DIR}}/notes/{{version}}.md")
    fi
    if [ -n "${SIGNATURE:-}" ]; then
      args+=(--signature "${SIGNATURE}")
    fi
    if [ -n "${SIGNATURE31:-}" ]; then
      args+=(--signature-sha3 "${SIGNATURE31}")
    fi
    swift Scripts/generate_appcast.swift "${args[@]}"

# Convenience recipe to run the full release pipeline.
release version notes="":
    just archive {{version}}
    just export {{version}}
    just zip {{version}}
    just generate-appcast {{version}} {{notes}}
