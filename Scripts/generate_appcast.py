#!/usr/bin/env python3
import argparse
import html
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or update Sparkle appcast entries")
    parser.add_argument("--version", required=True, help="Version identifier (Sparkle version)")
    parser.add_argument("--dist-dir", required=True, help="Directory containing the packaged zip")
    parser.add_argument("--update-dir", required=True, help="Directory containing the appcast.xml")
    parser.add_argument("--download-base", required=True, help="Base URL where the zip will be hosted")
    parser.add_argument("--min-system-version", required=True, help="Minimum macOS version supported")
    parser.add_argument("--notes-file", default="", help="Optional release notes file (Markdown/HTML)")
    return parser.parse_args()

def ensure_base_appcast(appcast_path: Path, download_base: str) -> None:
    if appcast_path.exists():
        return
    base_link = download_base.rstrip("/") + "/appcast.xml"
    template = f"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<rss xmlns:sparkle=\"http://www.andymatuschak.org/xml-namespaces/sparkle\" version=\"2.0\">\n  <channel>\n    <title>App Detective Updates</title>\n    <link>{base_link}</link>\n    <description>Release notes and downloads for App Detective.</description>\n    <language>en</language>\n  </channel>\n</rss>\n"""
    appcast_path.parent.mkdir(parents=True, exist_ok=True)
    appcast_path.write_text(template, encoding="utf-8")

def file_size_string(zip_path: Path) -> str:
    try:
        size = zip_path.stat().st_size
    except FileNotFoundError:
        print(f"Zip file not found at {zip_path}", file=sys.stderr)
        sys.exit(1)
    return str(size)

def load_notes(notes_path: Optional[Path]) -> str:
    default = "<p>Bug fixes and improvements.</p>"
    if not notes_path or not notes_path.exists():
        return default
    try:
        raw = notes_path.read_text(encoding="utf-8")
    except OSError:
        return default
    if not raw.strip():
        return default
    escaped = html.escape(raw)
    return f"<pre>\n{escaped}\n</pre>"

def rfc822_now() -> str:
    return datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")

def remove_existing_item(contents: str, version: str) -> str:
    pattern = re.compile(
        r"\s*<item>\s*<title>App Detective .*?<sparkle:version>" + re.escape(version) + r"</sparkle:version>.*?</item>",
        re.DOTALL,
    )
    return re.sub(pattern, "", contents)

def append_item(contents: str, item: str) -> str:
    marker = "</channel>"
    if marker not in contents:
        raise SystemExit("Malformed appcast: missing </channel> marker")
    return contents.replace(marker, item + "\n  " + marker)

def build_item(version: str, short_version: str, download_url: str, file_size: str, notes: str, min_system: str, signatures: dict[str, str]) -> str:
    enclosure_attrs = [
        f'url="{download_url}"',
        'sparkle:os="macos"',
        f'length="{file_size}"',
        'type="application/octet-stream"',
    ]
    if signatures.get("ed25519"):
        enclosure_attrs.insert(1, f'sparkle:edSignature="{signatures["ed25519"]}"')
    if signatures.get("ed25519sha3"):
        enclosure_attrs.insert(2, f'sparkle:edSignature31="{signatures["ed25519sha3"]}"')
    enclosure = "\n        ".join(enclosure_attrs)
    pub_date = rfc822_now()
    return f"""    <item>\n      <title>App Detective {short_version}</title>\n      <description>\n        <![CDATA[\n        {notes}\n        ]]>\n      </description>\n      <pubDate>{pub_date}</pubDate>\n      <sparkle:version>{version}</sparkle:version>\n      <sparkle:shortVersionString>{short_version}</sparkle:shortVersionString>\n      <enclosure\n        {enclosure}\n      />\n      <sparkle:minimumSystemVersion>{min_system}</sparkle:minimumSystemVersion>\n    </item>\n"""

def main() -> None:
    args = parse_args()
    dist_dir = Path(args.dist_dir)
    update_dir = Path(args.update_dir)
    zip_path = dist_dir / f"AppDetective-{args.version}.zip"
    appcast_path = update_dir / "appcast.xml"

    ensure_base_appcast(appcast_path, args.download_base)

    notes_path: Path | None = None
    if args.notes_file.strip():
        notes_path = Path(args.notes_file)
    else:
        fallback = update_dir / "notes" / f"{args.version}.md"
        if fallback.exists():
            notes_path = fallback

    notes_html = load_notes(notes_path)
    file_size = file_size_string(zip_path)
    short_version = os.environ.get("SHORT_VERSION", args.version)
    min_system_version = os.environ.get("MIN_SYSTEM_VERSION", args.min_system_version)

    signatures: dict[str, str] = {}
    if sig := os.environ.get("SIGNATURE"):
        signatures["ed25519"] = sig
    if sig31 := os.environ.get("SIGNATURE31"):
        signatures["ed25519sha3"] = sig31

    download_url = args.download_base.rstrip("/") + f"/AppDetective-{args.version}.zip"

    contents = appcast_path.read_text(encoding="utf-8")
    contents = remove_existing_item(contents, args.version)

    item = build_item(
        version=args.version,
        short_version=short_version,
        download_url=download_url,
        file_size=file_size,
        notes=notes_html,
        min_system=min_system_version,
        signatures=signatures,
    )

    updated = append_item(contents, item)
    appcast_path.write_text(updated, encoding="utf-8")
    print(f"Updated appcast at {appcast_path} with version {args.version}")

if __name__ == "__main__":
    main()
