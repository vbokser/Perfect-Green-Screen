#!/usr/bin/python3
"""Reserve the next app build number and generate Xcode's Info.plist prefix header."""

import fcntl
import os
from datetime import datetime, timezone
from pathlib import Path


def generate_metadata(counter_file: Path, header_file: Path, minimum_build: int) -> None:
    # Lock the persistent file itself, so simultaneous builds in different DerivedData
    # directories reserve distinct numbers without a stale lock directory after a crash.
    with counter_file.open("r+", encoding="utf-8") as counter:
        fcntl.flock(counter, fcntl.LOCK_EX)
        current_build = int(counter.read().strip())
        if current_build < 0 or minimum_build < 0:
            raise ValueError("Build numbers must be nonnegative integers")
        next_build = max(current_build, minimum_build) + 1
        counter.seek(0)
        counter.write(f"{next_build}\n")
        counter.truncate()
        counter.flush()
        os.fsync(counter.fileno())

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    header_file.parent.mkdir(parents=True, exist_ok=True)
    header_file.write_text(
        f"#define PGS_BUILD_NUMBER {next_build}\n"
        f"#define PGS_BUILD_TIMESTAMP {timestamp}\n",
        encoding="utf-8",
    )
    print(f"Perfect Green Screen: build {next_build}, built {timestamp}")


if __name__ == "__main__":
    project_root = Path(os.environ["SRCROOT"])
    generate_metadata(
        project_root / "BuildSupport" / "BuildNumber.txt",
        Path(os.environ["DERIVED_FILE_DIR"]) / "BuildMetadata.h",
        int(os.environ.get("CURRENT_PROJECT_VERSION", "0")),
    )
