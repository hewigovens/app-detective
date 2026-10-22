#!/usr/bin/env python3
"""Rewrite the Sparkle appcast with a single item for the release."""
import os
import sys
from datetime import datetime, timezone

if len(sys.argv) != 7:
    print("Usage: update-appcast.py <version> <build_number> <zip_path> <appcast_path> <signature> <minimum_system_version>")
    sys.exit(1)

version = sys.argv[1]
build_number = sys.argv[2]
zip_path = sys.argv[3]
appcast_path = sys.argv[4]
signature = sys.argv[5]
minimum_system_version = sys.argv[6]

file_size = os.path.getsize(zip_path)

pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")

appcast = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>App Detective</title>
        <link>https://raw.githubusercontent.com/hewigovens/app-detective/main/docs/appcast.xml</link>
        <description>App Detective updates</description>
        <language>en</language>
        <item>
            <title>Version {version}</title>
            <sparkle:version>{build_number}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <pubDate>{pub_date}</pubDate>
            <sparkle:minimumSystemVersion>{minimum_system_version}</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>https://github.com/hewigovens/app-detective/releases/tag/{version}</sparkle:releaseNotesLink>
            <enclosure url="https://github.com/hewigovens/app-detective/releases/download/{version}/AppDetective-{version}.zip"
                       sparkle:edSignature="{signature}"
                       length="{file_size}"
                       type="application/octet-stream"/>
        </item>
    </channel>
</rss>
"""

with open(appcast_path, "w") as f:
    f.write(appcast)

print(f"Updated {appcast_path}")
print(f"  Version: {version}")
print(f"  Size: {file_size}")
print(f"  Signature: {signature}")
