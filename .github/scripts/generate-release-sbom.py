#!/usr/bin/env python3
"""Generate a small, auditable CycloneDX SBOM from HardwareMon lock files."""

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import re
from datetime import datetime, timezone
import uuid


ROOT = Path(__file__).resolve().parents[2]


def _installed_distribution(name):
    try:
        return importlib.metadata.distribution(name)
    except importlib.metadata.PackageNotFoundError:
        return None


def _python_components():
    path = ROOT / "hardwaremon_app" / "backend_fastapi" / "requirements.txt"
    if not path.exists():
        return []
    declared_requirements = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line or line.startswith(("-", "http://", "https://")):
            continue
        match = re.match(r"([A-Za-z0-9_.-]+)\s*([<>=!~].+)?$", line)
        if match:
            declared_requirements[match.group(1)] = (match.group(2) or "").strip()

    components = {}
    queue = [(name, True) for name in declared_requirements]
    visited = set()
    while queue:
        name, direct = queue.pop(0)
        normalized = re.sub(r"[-_.]+", "-", name).lower()
        if normalized in visited:
            continue
        visited.add(normalized)
        distribution = _installed_distribution(name)
        version = distribution.version if distribution else None
        canonical_name = distribution.metadata.get("Name", name) if distribution else name
        bom_ref = f"pkg:pypi/{normalized}" + (f"@{version}" if version else "")
        component = {
            "type": "library",
            "bom-ref": bom_ref,
            "name": canonical_name,
            "purl": bom_ref,
            "scope": "required",
            "properties": [
                {"name": "hardwaremon:ecosystem", "value": "python"},
                {"name": "hardwaremon:dependencyType", "value": "direct" if direct else "transitive"},
                {"name": "hardwaremon:sourceFile", "value": "hardwaremon_app/backend_fastapi/requirements.txt"},
            ],
        }
        declared = declared_requirements.get(name)
        if declared is not None:
            component["properties"].append(
                {"name": "hardwaremon:declaredRequirement", "value": declared or "unpinned"}
            )
        if version:
            component["version"] = version
        components[bom_ref] = component

        if distribution:
            for requirement in distribution.requires or []:
                dependency = re.match(r"\s*([A-Za-z0-9_.-]+)", requirement)
                if dependency and "extra ==" not in requirement:
                    queue.append((dependency.group(1), False))
    return list(components.values())


def _dart_components():
    path = ROOT / "hardwaremon_app" / "pubspec.lock"
    if not path.exists():
        return []
    components = []
    current = None
    for line in path.read_text(encoding="utf-8").splitlines():
        package_match = re.match(r"^  ([A-Za-z0-9_]+):$", line)
        if package_match:
            if current and current.get("version"):
                components.append(current)
            name = package_match.group(1)
            current = {
                "type": "library",
                "name": name,
                "properties": [
                    {"name": "hardwaremon:ecosystem", "value": "dart"},
                    {"name": "hardwaremon:sourceFile", "value": "hardwaremon_app/pubspec.lock"},
                ],
            }
            continue
        if current is None:
            continue
        version_match = re.match(r'^    version: ["\']?([^"\']+)["\']?$', line)
        if version_match:
            version = version_match.group(1)
            purl = f"pkg:pub/{current['name']}@{version}"
            current.update(version=version, purl=purl, **{"bom-ref": purl})
        hash_match = re.match(r'^      sha256: ["\']?([0-9a-fA-F]{64})["\']?$', line)
        if hash_match:
            current["hashes"] = [{"alg": "SHA-256", "content": hash_match.group(1).lower()}]
        dependency_match = re.match(r'^    dependency: ["\']?([^"\']+)["\']?$', line)
        if dependency_match:
            current["scope"] = "required" if "direct" in dependency_match.group(1) else "optional"
    if current and current.get("version"):
        components.append(current)
    return components


def build_sbom(name, version, artifact):
    components = sorted(
        _python_components() + _dart_components(),
        key=lambda item: item["bom-ref"],
    )
    seed = f"{os.environ.get('GITHUB_REPOSITORY', 'HardwareMon')}:{os.environ.get('GITHUB_SHA', 'local')}:{artifact}"
    root_ref = f"pkg:github/{os.environ.get('GITHUB_REPOSITORY', 'HardwareMon')}@{version}"
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, seed)}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "tools": {
                "components": [
                    {
                        "type": "application",
                        "name": "HardwareMon release SBOM generator",
                        "version": "1",
                    }
                ]
            },
            "component": {
                "type": "application",
                "bom-ref": root_ref,
                "name": name,
                "version": version,
                "properties": [
                    {"name": "hardwaremon:releaseArtifact", "value": artifact},
                    {"name": "hardwaremon:gitCommit", "value": os.environ.get("GITHUB_SHA", "local")},
                ],
            },
        },
        "components": components,
        "dependencies": [
            {"ref": root_ref, "dependsOn": [item["bom-ref"] for item in components]},
            *[{"ref": item["bom-ref"], "dependsOn": []} for item in components],
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--name", default="HardwareMon")
    parser.add_argument("--version", required=True)
    parser.add_argument("--artifact", required=True)
    args = parser.parse_args()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(build_sbom(args.name, args.version, args.artifact), indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote CycloneDX SBOM: {output}")


if __name__ == "__main__":
    main()
