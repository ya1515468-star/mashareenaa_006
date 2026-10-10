#!/usr/bin/env python3
"""Collect license/notice files from Flutter's resolved package cache.

The script is dependency-free and never changes application code. Missing
license files are reported for human review instead of being guessed.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import url2pathname

LICENSE_NAMES = ("LICENSE", "LICENSE.txt", "LICENSE.md", "LICENSE-MIT", "LICENSE-APACHE", "COPYING", "NOTICE", "NOTICE.txt", "COPYRIGHT")
EXCLUDE = {"flutter", "flutter_test", "integration_test", "sky_engine", "flutter_localizations", "flutter_driver"}

def resolve_root(value: str, config_dir: Path) -> Path:
    parsed = urlparse(value)
    if parsed.scheme == "file":
        return Path(url2pathname(parsed.path)).resolve()
    return (config_dir / value).resolve()

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-config", default=".dart_tool/package_config.json")
    parser.add_argument("--output", default="THIRD_PARTY_NOTICES.txt")
    args = parser.parse_args()
    config_path = Path(args.package_config)
    if not config_path.is_file():
        raise SystemExit(f"Package configuration not found: {config_path}")
    data = json.loads(config_path.read_text(encoding="utf-8"))
    packages = sorted(data.get("packages", []), key=lambda p: p.get("name", "").lower())
    output = [
        "MASHAREENA third-party dependency license inventory",
        "Generated from .dart_tool/package_config.json in the CI build.",
        "This inventory is not legal advice; separately audit non-package media/assets.",
        "",
    ]
    missing = []
    for package in packages:
        name = package.get("name", "(unknown package)")
        if name in EXCLUDE:
            continue
        root = resolve_root(package.get("rootUri", ""), config_path.parent)
        matches = [root / n for n in LICENSE_NAMES if (root / n).is_file()]
        output.extend(["=" * 78, f"PACKAGE: {name}", f"SOURCE DIRECTORY: {root}"])
        if not matches:
            missing.append(name)
            output.append("LICENSE STATUS: No conventional LICENSE/COPYING/NOTICE file detected; review upstream metadata manually.")
        else:
            for license_path in matches:
                output.extend(["", f"--- {license_path.name} ---", license_path.read_text(encoding="utf-8", errors="replace").rstrip()])
        output.append("")
    output.extend(["=" * 78, "MANUAL REVIEW REQUIRED", "Packages without a conventional license file in the resolved package root:"])
    output.extend([f"- {name}" for name in missing] if missing else ["- None detected by this script."])
    output.extend(["", "This script cannot discover licenses for binary/image/audio/video assets or prove commercial rights. Review THIRD_PARTY_NOTICES.md and all assets before release."])
    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(output) + "\n", encoding="utf-8")
    print(f"Wrote {target}; packages reviewed: {len(packages) - len(EXCLUDE)}, missing license files: {len(missing)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
