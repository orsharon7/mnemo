#!/usr/bin/env python3
"""update-appcast.py — insert/refresh a Sparkle appcast.xml entry.

Usage:
    python3 scripts/update-appcast.py \\
        --appcast site/appcast.xml \\
        --version v0.6.0 \\
        --url https://github.com/orsharon7/mnemo/releases/download/v0.6.0/Mnemo-v0.6.0.dmg \\
        --ed-signature "BASE64SIG" \\
        --length 12345678 \\
        --notes "$(cat /tmp/notes.md)" \\
        --min-os 14.0

Creates the appcast file from a template if missing, otherwise inserts the new
item at the top of <channel> (and removes any existing item for the same
version so re-runs are idempotent).
"""

from __future__ import annotations

import argparse
import datetime
import os
import re
import sys
from pathlib import Path

TEMPLATE = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Mnemo</title>
        <link>https://orsharon7.github.io/mnemo/appcast.xml</link>
        <description>Mnemo updates</description>
        <language>en</language>
    </channel>
</rss>
"""


def build_item(*, version: str, pub_date: str, url: str, ed_sig: str,
               length: int, notes: str, min_os: str) -> str:
    version_bare = version.lstrip("v")
    return (
        "        <item>\n"
        f"            <title>Version {version_bare}</title>\n"
        f"            <pubDate>{pub_date}</pubDate>\n"
        f"            <sparkle:version>{version_bare}</sparkle:version>\n"
        f"            <sparkle:shortVersionString>{version_bare}</sparkle:shortVersionString>\n"
        f"            <sparkle:minimumSystemVersion>{min_os}</sparkle:minimumSystemVersion>\n"
        f"            <description><![CDATA[{notes.strip()}]]></description>\n"
        "            <enclosure\n"
        f'                url="{url}"\n'
        f'                sparkle:edSignature="{ed_sig}"\n'
        f'                length="{length}"\n'
        '                type="application/octet-stream"/>\n'
        "        </item>\n"
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--appcast", required=True, type=Path)
    p.add_argument("--version", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--ed-signature", required=True)
    p.add_argument("--length", required=True, type=int)
    p.add_argument("--notes", required=True)
    p.add_argument("--min-os", default="14.0")
    args = p.parse_args()

    pub_date = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S +0000"
    )

    new_item = build_item(
        version=args.version,
        pub_date=pub_date,
        url=args.url,
        ed_sig=args.ed_signature,
        length=args.length,
        notes=args.notes,
        min_os=args.min_os,
    )

    args.appcast.parent.mkdir(parents=True, exist_ok=True)

    if args.appcast.exists():
        xml = args.appcast.read_text()
    else:
        xml = TEMPLATE

    # Drop any existing item for this version (idempotent re-runs).
    version_bare = args.version.lstrip("v")
    xml = re.sub(
        r"\s*<item>\s*<title>Version " + re.escape(version_bare) + r"</title>.*?</item>\n?",
        "\n",
        xml,
        flags=re.DOTALL,
    )

    if "<channel>" not in xml:
        print("error: appcast.xml has no <channel> element", file=sys.stderr)
        return 1

    xml = xml.replace("<channel>", "<channel>\n" + new_item.rstrip() + "\n", 1)

    # Collapse runs of >2 blank lines.
    xml = re.sub(r"\n{3,}", "\n\n", xml)

    args.appcast.write_text(xml)
    print(f"→ Wrote {args.appcast} (version {version_bare})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
