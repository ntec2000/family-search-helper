"""Check native iOS wiring without requiring a Mac or private genealogy data."""
from pathlib import Path
import plistlib
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class IosConfigurationTests(unittest.TestCase):
    def test_camera_and_photo_permissions_are_declared(self):
        with (ROOT / "ios/Runner/Info.plist").open("rb") as handle:
            info = plistlib.load(handle)
        self.assertEqual(info["CFBundleDisplayName"], "가족역사 기록 도우미")
        for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "NSMicrophoneUsageDescription"):
            self.assertTrue(info.get(key))

    def test_chinese_recognizer_has_native_model_dependency(self):
        pod = (ROOT / "ios/Podfile").read_text()
        self.assertIn("pod 'GoogleMLKit/TextRecognitionChinese', '~> 9.0.0'", pod)
        self.assertIn("platform :ios, '15.5'", pod)
        self.assertIn("PERMISSION_CAMERA=1", pod)
        self.assertIn("PERMISSION_PHOTOS=1", pod)

    def test_xcode_references_resolve(self):
        project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        self.assertNotIn("{{", project)
        self.assertNotIn("IPHONEOS_DEPLOYMENT_TARGET = 13.0", project)
        for name in ("AppDelegate.swift", "SceneDelegate.swift", "Runner-Bridging-Header.h", "Base.lproj/Main.storyboard", "Base.lproj/LaunchScreen.storyboard"):
            self.assertTrue((ROOT / "ios/Runner" / name).is_file(), name)
        for p in (ROOT / "ios").rglob("*"):
            if p.suffix in (".plist", ".storyboard", ".xcscheme", ".xcworkspacedata", ".xcsettings"):
                ET.parse(p)


if __name__ == "__main__":
    unittest.main()
