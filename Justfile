set shell := ["bash", "-lc"]
set export

default:
	@just --list

PROJECT := "AppDetective/AppDetective.xcodeproj"
SCHEME := "AppDetective"
ARCHIVE_DIR := "build/archive"
EXPORT_DIR := "build/export"
DIST_DIR := "build/dist"

# Build the project (Debug) using xcbeautify
build:
	set -o pipefail && xcodebuild -project {{PROJECT}} -scheme {{SCHEME}} build | xcbeautify

# Run tests using xcbeautify
test:
	set -o pipefail && xcodebuild -project {{PROJECT}} -scheme {{SCHEME}} test | xcbeautify

# Clean build artifacts
clean:
	set -o pipefail && xcodebuild -project {{PROJECT}} -scheme {{SCHEME}} clean | xcbeautify

# Archive the app for distribution.
archive version:
	set -euxo pipefail
	mkdir -p {{ARCHIVE_DIR}}
	xcodebuild \
	  -project {{PROJECT}} \
	  -scheme {{SCHEME}} \
	  -configuration Release \
	  -archivePath {{ARCHIVE_DIR}}/AppDetective-{{version}}.xcarchive \
	  archive | xcbeautify

# Export the .app bundle from the archive into build/export.
export version:
	set -euxo pipefail
	rm -rf "{{EXPORT_DIR}}/AppDetective-{{version}}"
	mkdir -p "{{EXPORT_DIR}}/AppDetective-{{version}}"
	rsync -a "{{ARCHIVE_DIR}}/AppDetective-{{version}}.xcarchive/Products/Applications/AppDetective.app" "{{EXPORT_DIR}}/AppDetective-{{version}}/"

# Create a zip from the exported .app bundle.
zip version:
	set -euxo pipefail
	mkdir -p {{DIST_DIR}}
	ditto -c -k --sequesterRsrc --keepParent "{{EXPORT_DIR}}/AppDetective-{{version}}/AppDetective.app" "{{DIST_DIR}}/AppDetective-{{version}}.zip"

# Convenience recipe to run the full release pipeline.
release version:
	just archive {{version}}
	just export {{version}}
	just zip {{version}}
	just update-cask {{version}}

# Update the Homebrew cask with the new version and SHA.
update-cask version:
	set -euxo pipefail; \
	zip_path="{{DIST_DIR}}/AppDetective-{{version}}.zip"; \
	if [ ! -f "$zip_path" ]; then echo "Expected archive at $zip_path. Run 'just zip {{version}}' first." >&2; exit 1; fi; \
	sha256=$(shasum -a 256 "$zip_path" | awk '{print $1}'); \
	cask_path="../homebrew-tap/Casks/app-detective.rb"; \
	tmp_file=$(mktemp); \
	awk -v version="{{version}}" -v sha="$sha256" '{ if ($0 ~ /version "/) sub(/"[^"]+"/, "\"" version "\""); if ($0 ~ /sha256 "/) sub(/"[^"]+"/, "\"" sha "\""); print }' "$cask_path" > "$tmp_file"; \
	mv "$tmp_file" "$cask_path"
