#!/usr/bin/env python3
"""Rewrite the Sparkle appcast with a single item for the release.

The release notes come from releases/<version>.md, rendered into the item's
description so Sparkle's update prompt shows them instead of loading a web page.
"""
import os
import re
import sys
from datetime import datetime, timezone
from html import escape
from string import Template

if len(sys.argv) != 7:
    print("Usage: update-appcast.py <version> <build_number> <zip_path> <appcast_path> <signature> <minimum_system_version>")
    sys.exit(1)

version = sys.argv[1]
build_number = sys.argv[2]
zip_path = sys.argv[3]
appcast_path = sys.argv[4]
signature = sys.argv[5]
minimum_system_version = sys.argv[6]

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def inline(text: str) -> str:
    text = escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", text)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)


# Covers what releases/*.md use: headings, nested bullets, and inline emphasis, code, and links.
def markdown_to_html(markdown: str) -> str:
    html = []
    depth = 0
    for line in markdown.splitlines():
        bullet = re.match(r"^( *)- (.*)$", line)
        if bullet:
            level = len(bullet.group(1)) // 2 + 1
            if level > depth:
                html.append("<ul>" * (level - depth))
            else:
                html.append("</li>" + "</ul></li>" * (depth - level))
            depth = level
            html.append(f"<li>{inline(bullet.group(2))}")
            continue
        if depth and not line.strip():
            continue
        if depth:
            html.append("</li>" + "</ul></li>" * (depth - 1) + "</ul>")
            depth = 0
        heading = re.match(r"^(#{2,3}) (.*)$", line)
        if heading:
            # "## What's new" is the template's own title, so only ### sections become headings.
            if len(heading.group(1)) == 3:
                html.append(f"<h2>{inline(heading.group(2))}</h2>")
        elif line.strip():
            html.append(f"<p>{inline(line.strip())}</p>")
    if depth:
        html.append("</li>" + "</ul></li>" * (depth - 1) + "</ul>")
    return "\n".join(html)


notes_path = os.path.join(repo_root, "releases", f"{version}.md")
with open(notes_path) as f:
    notes = markdown_to_html(f.read())
if not notes:
    print(f"ERROR: release notes are empty at {notes_path}", file=sys.stderr)
    sys.exit(1)

file_size = os.path.getsize(zip_path)
published_at = datetime.now(timezone.utc)
pub_date = published_at.strftime("%a, %d %b %Y %H:%M:%S %z")

with open(os.path.join(repo_root, "scripts", "release-notes-template.html")) as f:
    page = Template(f.read()).substitute(
        app_name="App Detective",
        version=escape(version),
        date_iso=published_at.date().isoformat(),
        date_label=f"{published_at:%B} {published_at.day}, {published_at.year}",
        notes=notes,
    )
if "]]>" in page:
    print(f"ERROR: release notes contain a CDATA terminator: {notes_path}", file=sys.stderr)
    sys.exit(1)

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
            <description><![CDATA[
{page}
            ]]></description>
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
