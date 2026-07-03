#!/usr/bin/env python3
"""Create portable release checksums and human-readable provenance metadata."""

import argparse
from datetime import datetime, timezone
import glob
import hashlib
import json
import os
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--checksums-name", required=True)
    parser.add_argument("--metadata-name", required=True)
    parser.add_argument("artifacts", nargs="+")
    args = parser.parse_args()

    paths = []
    for pattern in args.artifacts:
        matches = [Path(item) for item in glob.glob(pattern)]
        paths.extend(path for path in matches if path.is_file())
    paths = sorted(set(paths), key=lambda item: item.name.lower())
    if not paths:
        raise SystemExit("No release artifacts matched; checksums were not generated.")

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    subjects = [
        {"name": path.name, "sha256": sha256(path), "size": path.stat().st_size}
        for path in paths
    ]
    checksum_path = output_dir / args.checksums_name
    checksum_path.write_text(
        "".join(f"{subject['sha256']} *{subject['name']}\n" for subject in subjects),
        encoding="utf-8",
    )
    metadata = {
        "schema": "hardwaremon-release-metadata-v1",
        "generatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "repository": os.environ.get("GITHUB_REPOSITORY", "local"),
        "commit": os.environ.get("GITHUB_SHA", "local"),
        "ref": os.environ.get("GITHUB_REF", "local"),
        "workflow": os.environ.get("GITHUB_WORKFLOW", "local"),
        "runId": os.environ.get("GITHUB_RUN_ID", "local"),
        "runAttempt": os.environ.get("GITHUB_RUN_ATTEMPT", "local"),
        "subjects": subjects,
    }
    metadata_path = output_dir / args.metadata_name
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {checksum_path} and {metadata_path} for {len(subjects)} artifact(s).")


if __name__ == "__main__":
    main()
