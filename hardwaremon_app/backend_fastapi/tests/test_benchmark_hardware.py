import unittest

from benchmark.hardware import classify_storage_type


class BenchmarkHardwareTests(unittest.TestCase):
    def test_storage_type_classification(self):
        self.assertEqual(
            classify_storage_type({"interface_type": "NVMe", "model": "Fast Disk"}),
            "NVMe",
        )
        self.assertEqual(
            classify_storage_type({"media_type": "SSD", "interface_type": "SATA"}),
            "SSD",
        )
        self.assertEqual(classify_storage_type({"rotational": 1}), "HDD")
        self.assertEqual(classify_storage_type({"interface_type": "SATA"}), "SATA")


if __name__ == "__main__":
    unittest.main()
