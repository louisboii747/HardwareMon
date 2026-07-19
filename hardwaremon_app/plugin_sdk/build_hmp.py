from __future__ import annotations

import argparse
import json
import re
import zipfile
from pathlib import Path


PLUGIN_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{2,79}$")


def build(source: Path, output: Path) -> None:
    manifest_path = source / "hardwaremon-plugin.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    plugin_id = str(manifest.get("id", ""))
    if not PLUGIN_ID.fullmatch(plugin_id) or source.name != plugin_id:
        raise SystemExit("Source directory and manifest id must match")
    if manifest.get("api_version") != 1:
        raise SystemExit("api_version must be 1")
    entrypoint = source / str(manifest.get("entrypoint", {}).get("path", ""))
    if not entrypoint.is_file() or source.resolve() not in entrypoint.resolve().parents:
        raise SystemExit("Entrypoint is missing or outside the plugin directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in source.rglob("*"):
            if path.is_file() and "__pycache__" not in path.parts:
                archive.write(path, Path(plugin_id) / path.relative_to(source))
    print(f"Built {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build a HardwareMon .hmp plugin package")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    values = parser.parse_args()
    build(values.source.resolve(), values.output.resolve())
