"""Prepare the iOS icon from the existing Android brand asset on macOS."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
DESTINATION = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def main():
    if sys.platform != "darwin":
        raise SystemExit("Run this iOS preparation step on macOS (sips is required).")
    if not SOURCE.is_file():
        raise SystemExit("The existing Android brand icon is missing.")
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-z", "1024", "1024", str(SOURCE), "--out", str(DESTINATION)], check=True)


if __name__ == "__main__":
    main()
