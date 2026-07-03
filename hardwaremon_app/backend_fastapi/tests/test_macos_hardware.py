import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from telemetry import macos_hardware
from telemetry import system


class MacOSHardwareParsingTests(unittest.TestCase):
    def tearDown(self):
        macos_hardware.read_macos_hardware_info.cache_clear()

    def test_system_profiler_parses_every_supported_m_series(self):
        for generation in ("M1", "M2", "M3", "M4"):
            with self.subTest(generation=generation):
                parsed = macos_hardware.parse_system_profiler_hardware(
                    f"""
                    Hardware:

                        Model Name: MacBook Air
                        Model Identifier: Mac99,1
                        Chip: Apple {generation}
                    """
                )
                self.assertEqual(
                    macos_hardware.choose_macos_cpu_name("arm64", profiler=parsed),
                    f"Apple {generation}",
                )

    def test_unknown_apple_silicon_never_displays_generic_arm(self):
        for generic_name in ("arm", "arm64", "aarch64", ""):
            with self.subTest(generic_name=generic_name):
                self.assertEqual(
                    macos_hardware.choose_macos_cpu_name(
                        "arm64",
                        brand_string=generic_name,
                        processor=generic_name,
                    ),
                    "Apple Silicon",
                )

    def test_intel_mac_uses_brand_string(self):
        self.assertEqual(
            macos_hardware.choose_macos_cpu_name(
                "x86_64",
                brand_string="Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz",
            ),
            "Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz",
        )

    def test_profiler_is_cached_across_hardware_reads(self):
        outputs = {
            "machdep.cpu.brand_string": "arm64",
            "hw.model": "Mac16,2",
        }

        def fake_sysctl(name):
            return outputs[name]

        with (
            patch.object(macos_hardware.platform, "machine", return_value="arm64"),
            patch.object(macos_hardware.platform, "processor", return_value="arm"),
            patch.object(macos_hardware, "_sysctl_value", side_effect=fake_sysctl),
            patch.object(
                macos_hardware,
                "_run_command",
                return_value="Chip: Apple M4\nModel Name: MacBook Air",
            ) as profiler,
        ):
            first = macos_hardware.read_macos_hardware_info()
            second = macos_hardware.read_macos_hardware_info()

        self.assertEqual(first["cpu_name"], "Apple M4")
        self.assertIs(first, second)
        profiler.assert_called_once()


class MacOSTelemetryTests(unittest.TestCase):
    def test_restricted_metrics_are_null_and_explained(self):
        hardware = {
            "cpu_name": "Apple M4",
            "chip_name": "Apple M4",
            "architecture": "arm64",
            "model_identifier": "Mac16,2",
            "model_name": "MacBook Air",
        }
        with (
            patch.object(system, "IS_MACOS", True),
            patch.object(system, "read_macos_hardware_info", return_value=hardware),
            patch.object(system, "collect_basic_stats", return_value={
                "cpu": 17,
                "ram": 42,
                "ram_used": 6.7,
                "ram_available": 9.3,
                "ram_total": 16.0,
                "disk": 51,
            }),
            patch.object(system, "collect_platform_info", return_value={"name": "macOS"}),
        ):
            stats = system.collect_macos_stats()

        for metric in (
            "cpu_temp",
            "gpu_temp",
            "cpu_power",
            "gpu_power",
            "cpu_clock",
            "gpu_usage",
            "gpu_vram_used",
        ):
            self.assertIsNone(stats[metric])
            self.assertIn(metric, stats["unavailable_metrics"])
        self.assertEqual(stats["cpu_name"], "Apple M4")
        self.assertTrue(stats["capabilities"]["supports_process_list"])
        self.assertFalse(stats["capabilities"]["supports_process_kill"])


if __name__ == "__main__":
    unittest.main()
