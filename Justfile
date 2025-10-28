set shell := ["bash", "-lc"]
set export

default:
	@just --list

PROJECT := "AppDetective/AppDetective.xcodeproj"
SCHEME := "AppDetective"
ARCHIVE_DIR := "build/archive"
EXPORT_DIR := "build/export"
DIST_DIR := "build/dist"
UPDATE_DIR := "update"
DOWNLOAD_BASE := "https://hewig.dev/appdetective"
MIN_SYSTEM_VERSION := "13.0"

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
	rm -rf "{{EXPORT_DIR}}/AppDetective-{{version}}"
	mkdir -p "{{EXPORT_DIR}}/AppDetective-{{version}}"
	rsync -a "{{ARCHIVE_DIR}}/AppDetective-{{version}}.xcarchive/Products/Applications/AppDetective.app" "{{EXPORT_DIR}}/AppDetective-{{version}}/"

# Create a Sparkle-friendly zip from the exported .app bundle.
zip version:
	set -euxo pipefail
	mkdir -p {{DIST_DIR}}
	ditto -c -k --sequesterRsrc --keepParent "{{EXPORT_DIR}}/AppDetective-{{version}}/AppDetective.app" "{{DIST_DIR}}/AppDetective-{{version}}.zip"

# Generate or update the Sparkle appcast entry for the provided version.
generate-appcast version notes="":
    set -euxo pipefail
    python3 scripts/generate_appcast.py \
      --version {{version}} \
      --dist-dir {{DIST_DIR}} \
      --update-dir {{UPDATE_DIR}} \
      --download-base {{DOWNLOAD_BASE}} \
      --min-system-version {{MIN_SYSTEM_VERSION}} \
      --notes-file "{{notes}}"

# Convenience recipe to run the full release pipeline.
release version notes="":
	just archive {{version}}
	just export {{version}}
	just zip {{version}}
	just generate-appcast {{version}} {{notes}}
