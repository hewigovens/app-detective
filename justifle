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
	set -o pipefail && xcodebuild -project {{PROJECT}} -scheme {{SCHEME}} build CODE_SIGNING_ALLOWED=NO | xcbeautify

# Run tests using xcbeautify
test:
	set -o pipefail && xcodebuild -project {{PROJECT}} -scheme {{SCHEME}} test CODE_SIGNING_ALLOWED=NO | xcbeautify

# Clean build artifacts
clean:
	set -o pipefail && xcodebuild -project {{PROJECT}} -scheme {{SCHEME}} clean CODE_SIGNING_ALLOWED=NO | xcbeautify

# Archive the app for distribution.
archive version:
	#!/usr/bin/env bash
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
	#!/usr/bin/env bash
	set -euxo pipefail
	rm -rf "{{EXPORT_DIR}}/AppDetective-{{version}}"
	mkdir -p "{{EXPORT_DIR}}/AppDetective-{{version}}"
	# Export with proper signing using exportOptions.plist
	xcodebuild -exportArchive \
	  -archivePath "{{ARCHIVE_DIR}}/AppDetective-{{version}}.xcarchive" \
	  -exportPath "{{EXPORT_DIR}}/AppDetective-{{version}}" \
	  -exportOptionsPlist config/exportOptions.plist | xcbeautify

# Create a zip from the exported .app bundle.
zip version:
	#!/usr/bin/env bash
	set -euxo pipefail
	mkdir -p {{DIST_DIR}}
	ditto -c -k --sequesterRsrc --keepParent "{{EXPORT_DIR}}/AppDetective-{{version}}/AppDetective.app" "{{DIST_DIR}}/AppDetective-{{version}}.zip"

# Create a GitHub release if it doesn't exist.
create-release version:
	#!/usr/bin/env bash
	set -euo pipefail
	if gh release view {{version}} &>/dev/null; then
		echo "Release {{version}} already exists"
	else
		echo "Creating release {{version}}"
		gh release create {{version}} --draft --title "{{version}}" --notes "Release {{version}}"
	fi

# Notarize the exported app bundle.
notarize version:
	#!/usr/bin/env bash
	set -euxo pipefail
	app_path="{{EXPORT_DIR}}/AppDetective-{{version}}/AppDetective.app"
	if [ ! -d "$app_path" ]; then
		echo "App bundle not found at $app_path" >&2
		exit 1
	fi
	# Create a temporary zip for notarization
	temp_zip=$(mktemp -d)/AppDetective.zip
	echo "Creating temporary zip for notarization..."
	ditto -c -k --sequesterRsrc --keepParent "$app_path" "$temp_zip"
	echo "Submitting app for notarization..."
	xcrun notarytool submit "$temp_zip" --keychain-profile "notarytool" --wait
	echo "Stapling notarization ticket to app..."
	xcrun stapler staple "$app_path"
	# Clean up temp zip
	rm -f "$temp_zip"

# Upload the zip to the GitHub release.
upload-release version:
	#!/usr/bin/env bash
	set -euxo pipefail
	zip_path="{{DIST_DIR}}/AppDetective-{{version}}.zip"
	if [ ! -f "$zip_path" ]; then
		echo "Zip file not found at $zip_path" >&2
		exit 1
	fi
	echo "Uploading $zip_path to release {{version}}"
	gh release upload {{version}} "$zip_path" --clobber

# Convenience recipe to run the full release pipeline.
release version:
	just create-release {{version}}
	just archive {{version}}
	just export {{version}}
	just notarize {{version}}
	just zip {{version}}
	just upload-release {{version}}
	just update-cask {{version}}

# Update the Homebrew cask with the new version and SHA.
update-cask version:
	#!/usr/bin/env bash
	set -euxo pipefail
	zip_path="{{DIST_DIR}}/AppDetective-{{version}}.zip"
	if [ ! -f "$zip_path" ]; then
		echo "Expected archive at $zip_path. Run 'just zip {{version}}' first." >&2
		exit 1
	fi
	sha256=$(shasum -a 256 "$zip_path" | cut -d' ' -f1)
	cask_path="../tap/Casks/app-detective.rb"
	sed -i '' \
	  -e 's/version "[^"]*"/version "{{version}}"/' \
	  -e "s/sha256 \"[^\"]*\"/sha256 \"$sha256\"/" \
	  "$cask_path"
