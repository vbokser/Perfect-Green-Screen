"""Checks for persistent build numbering; all state lives in temporary projects."""

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

SCRIPT = Path(__file__).with_name("generate-build-metadata.py")
spec = importlib.util.spec_from_file_location("build_metadata", SCRIPT)
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class BuildMetadataTests(unittest.TestCase):
    def test_sequential_builds_increment_and_write_a_utc_timestamp(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            counter = root / "BuildNumber.txt"
            header = root / "BuildMetadata.h"
            counter.write_text("23\n")
            metadata.generate_metadata(counter, header, 23)
            self.assertEqual(counter.read_text(), "24\n")
            self.assertIn("#define PGS_BUILD_NUMBER 24\n", header.read_text())
            timestamp = header.read_text().split("PGS_BUILD_TIMESTAMP ")[1].strip()
            datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ")
            metadata.generate_metadata(counter, header, 23)
            self.assertEqual(counter.read_text(), "25\n")

    def test_build_setting_can_raise_the_minimum_without_reusing_numbers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            counter = root / "BuildNumber.txt"
            counter.write_text("23\n")
            metadata.generate_metadata(counter, root / "BuildMetadata.h", 100)
            self.assertEqual(counter.read_text(), "101\n")

    def test_concurrent_builds_reserve_unique_numbers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "BuildSupport").mkdir()
            counter = root / "BuildSupport/BuildNumber.txt"
            counter.write_text("23\n")

            def build(index):
                output = root / str(index)
                environment = dict(os.environ, SRCROOT=str(root), DERIVED_FILE_DIR=str(output), CURRENT_PROJECT_VERSION="23")
                subprocess.run([sys.executable, str(SCRIPT)], env=environment, check=True, capture_output=True, text=True)
                return int((output / "BuildMetadata.h").read_text().splitlines()[0].split()[-1])

            with ThreadPoolExecutor(max_workers=8) as executor:
                numbers = list(executor.map(build, range(8)))
            self.assertEqual(sorted(numbers), list(range(24, 32)))
            self.assertEqual(counter.read_text(), "31\n")


if __name__ == "__main__":
    unittest.main()
