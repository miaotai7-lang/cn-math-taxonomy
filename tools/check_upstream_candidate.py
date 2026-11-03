#!/usr/bin/env python3
"""Non-executing structural and local-customization checks for upstream candidates.

This program must be loaded from the trusted fork main branch before merging
upstream; do not execute the validator from newly merged upstream content.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SUBJECTS = ("math", "chinese", "science", "morality", "history", "geography", "english", "physics")
REQUIRED_FILES = (
    "index.html", "LICENSE", ".nojekyll", "manifest.webmanifest", "sw.js",
    "assets/site.css", "assets/home.js", "assets/stats.js", "assets/stats-config.js",
    "assets/pwa.js", "explore/index.html", "explore/app.js",
    "diagnose/index.html", "diagnose/app.js", "diagnose/engine.js",
    "diagnose/share.js", "children/index.html", "assets/children.js",
)
DATA_FILES = (
    "topics.json", "questions.json", "dependencies.json",
    "cn-curriculum-standards.json", "id-aliases.json",
)


def check(root: Path) -> list[str]:
    errors: list[str] = []
    for name in REQUIRED_FILES:
        p = root / name
        if not p.is_file() or p.stat().st_size == 0:
            errors.append(f"Required site file is missing or empty: {name}")

    for name in DATA_FILES:
        p = root / "data" / name
        if not p.is_file() or p.stat().st_size == 0:
            errors.append(f"Required learning data is missing or empty: data/{name}")
            continue
        try:
            with p.open("r", encoding="utf-8") as handle:
                obj = json.load(handle)
            if not isinstance(obj, (list, dict)) or not obj:
                errors.append(f"Learning data is empty or has unexpected root type: data/{name}")
        except (OSError, UnicodeError, ValueError) as exc:
            errors.append(f"Learning data cannot be parsed: data/{name}: {exc}")

    if (root / "LICENSE").is_file():
        license_text = (root / "LICENSE").read_text(encoding="utf-8")
        if "Attribution-NonCommercial 4.0" not in license_text:
            errors.append("Root CC BY-NC 4.0 license attribution is missing or changed")

    if (root / "index.html").is_file():
        html = (root / "index.html").read_text(encoding="utf-8")
        for subject in SUBJECTS:
            if f'data-subject="{subject}"' not in html:
                errors.append(f"Homepage subject selector is missing: {subject}")

    config = root / "assets/stats-config.js"
    if config.is_file():
        text = config.read_text(encoding="utf-8")
        for key in ("cloudflareToken", "endpoint"):
            # Require the active JS assignment (not just a comment) to be the empty string.
            lines = [line.split("//", 1)[0] for line in text.splitlines()]
            assignments = [line for line in lines if re.search(r"^\s*" + key + r"\s*:", line)]
            if len(assignments) != 1 or not re.search(r"^\s*" + key + r"\s*:\s*(['\"])\1\s*,?\s*$", assignments[0]):
                errors.append(f"Upstream analytics configuration is not disabled: {key}")

    share = root / "diagnose/share.js"
    if share.is_file():
        source = share.read_text(encoding="utf-8")
        if not re.search(r"\bvar\s+SHARE_URL\s*=\s*new\s+URL\s*\(\s*['\"]\.\./\?from=share['\"]\s*,\s*window\.location\.href\s*\)\.href\s*;", source):
            errors.append("Share URL does not point to the locally hosted site")

    return errors


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors = check(root)
    if errors:
        for msg in errors:
            print(f"ERROR: {msg}", file=sys.stderr)
        return 1
    print("PASS: eight subject links, required files, JSON data, attribution, analytics and sharing safeguards")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
