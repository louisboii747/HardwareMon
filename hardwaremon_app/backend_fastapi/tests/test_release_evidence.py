import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def _load_script(name, filename):
    spec = importlib.util.spec_from_file_location(
        name,
        ROOT / ".github" / "scripts" / filename,
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


sbom = _load_script("hardwaremon_release_sbom", "generate-release-sbom.py")
metadata = _load_script(
    "hardwaremon_release_metadata",
    "generate-release-metadata.py",
)


class ReleaseEvidenceTests(unittest.TestCase):
    def test_cyclonedx_sbom_contains_locked_dart_and_python_components(self):
        document = sbom.build_sbom("HardwareMon", "test", "test-artifact")
        components = document["components"]

        self.assertEqual(document["bomFormat"], "CycloneDX")
        self.assertEqual(document["specVersion"], "1.5")
        self.assertTrue(
            any(item["name"].lower() == "fastapi" for item in components)
        )
        self.assertTrue(any(item["name"] == "flutter" for item in components))

    def test_release_checksum_uses_sha256(self):
        expected = (
            "834bb27a3f186922f5fc5c4da2d12afcf2476a82b6f61237f92e4f63c5ba5f4c"
        )
        self.assertEqual(metadata.sha256(Path(__file__)), self._current_file_hash())
        self.assertEqual(len(expected), 64)

    def _current_file_hash(self):
        import hashlib

        return hashlib.sha256(Path(__file__).read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main()
