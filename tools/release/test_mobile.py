"""Build-contract checks: platform metadata, shipping resources and local configuration safety."""

import configparser
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("mobile", Path(__file__).with_name("mobile.py"))
mobile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mobile)


class MobileBuildTests(unittest.TestCase):
    def presets(self) -> configparser.ConfigParser:
        config = configparser.ConfigParser(interpolation=None)
        config.read_string(mobile.render_presets(mobile.settings(), "ABC1234567"))
        return config

    def test_platforms_share_identity_and_version(self) -> None:
        config = self.presets()
        android = config["preset.0.options"]
        play = config["preset.1.options"]
        ios = config["preset.2.options"]
        self.assertEqual(android["package/unique_name"], ios["application/bundle_identifier"])
        self.assertEqual(android["package/unique_name"], play["package/unique_name"])
        self.assertEqual(android["version/name"], ios["application/short_version"])
        self.assertEqual(android["version/code"], ios["application/version"].strip('"'))
        self.assertEqual(android["version/code"], play["version/code"])

    def test_phone_builds_ship_data_but_exclude_analytics_and_scratch(self) -> None:
        config = self.presets()
        for index in range(3):
            preset = config[f"preset.{index}"]
            for path in ["assets/art/*.json", "game/config/balance.json"]:
                self.assertIn(path, preset["include_filter"])
            for path in ["addons/*", "tests/*", "tools/*", "docs/*", "Claude outputs/*",
                         "output/*", "out/*", "game/config/analytics.json"]:
                self.assertIn(path, preset["exclude_filter"])
        for index in range(2):
            options = config[f"preset.{index}.options"]
            self.assertEqual(options["permissions/vibrate"], "true")
            self.assertEqual(options["permissions/internet"], "false")

    def test_store_build_uses_bundle_and_mac_handoff_exports_project_only(self) -> None:
        config = self.presets()
        self.assertEqual(config["preset.1.options"]["gradle_build/use_gradle_build"], "true")
        self.assertEqual(config["preset.1.options"]["gradle_build/export_format"], "1")
        ios = config["preset.2.options"]
        self.assertEqual(ios["application/export_project_only"], "true")
        self.assertEqual(ios["application/targeted_device_family"], "2")
        for section in config.sections():
            self.assertFalse(any(key.startswith("keystore/") for key in config[section]))

    def test_invalid_identifiers_cannot_inject_config(self) -> None:
        for app_id in ['com.game.bad"', "com.game\nname", "example", "com.UPPER.game", "com.game.bad_name"]:
            with self.assertRaises(ValueError):
                mobile.settings(app_id)
        with self.assertRaises(ValueError):
            mobile.render_presets(mobile.settings(), 'bad"\nteam')

    def test_ios_project_only_checks_the_project_not_an_unbuilt_ipa(self) -> None:
        destination = Path("exports/ios/dust_in_space.ipa")
        self.assertEqual(mobile.expected_output("ios", destination),
                         Path("exports/ios/dust_in_space.xcodeproj/project.pbxproj"))

    def test_existing_local_presets_are_preserved_and_not_overwritten_again(self) -> None:
        with tempfile.TemporaryDirectory() as directory, patch.object(mobile, "ROOT", Path(directory)):
            target = Path(directory) / "export_presets.cfg"
            target.write_text("original local settings", encoding="utf-8")
            mobile.configure(mobile.settings(), "")
            backup = Path(directory) / "output/release/original_export_presets.cfg"
            self.assertEqual(backup.read_text(), "original local settings")
            mobile.configure(mobile.settings(), "ABC1234567")
            self.assertEqual(backup.read_text(), "original local settings")
            target.write_text("another local preset", encoding="utf-8")
            with self.assertRaises(ValueError):
                mobile.configure(mobile.settings(), "")
            self.assertEqual(target.read_text(), "another local preset")


if __name__ == "__main__":
    unittest.main()
