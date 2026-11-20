import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch


BIN = Path(__file__).resolve().parents[1] / "targets/all/trees/home/.local/bin"


class DesktopTests(unittest.TestCase):
    def test_waybar_only_constructs_available_modules(self):
        bar_config = runpy.run_path(str(BIN / "lixx-waybar"))["bar_config"]
        devices = Path(self.enterContext(tempfile.TemporaryDirectory()))
        config = devices / "waybar"
        battery = devices / "power_supply/BAT0"
        battery.mkdir(parents=True)
        for name in ("uevent", "status", "charge_now"):
            (battery / name).touch()
        (battery / "type").write_text("Battery\n")
        (battery / "scope").write_text("Device\n")
        with patch("shutil.which", return_value=None):
            settings = bar_config(config, devices)
        self.assertEqual(settings, {
            "include": [str(config / "config.jsonc")],
            "battery": {"hosts": []}, "bluetooth": {"hosts": []}, "custom/voxtype": {"hosts": []},
        })
        (battery / "scope").write_text("System\n")
        (devices / "bluetooth/hci0").mkdir(parents=True)
        with patch("shutil.which", side_effect=lambda name: "/usr/bin/" + name):
            self.assertEqual(bar_config(config, devices), {"include": [str(config / "config.jsonc")]})

    def test_pomodoro_countdown_pause_and_phase_change(self):
        state = runpy.run_path(str(BIN / "lixx-pomodoro"))["state"]
        path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "timer"
        path.touch()
        with patch("time.monotonic", return_value=100):
            self.assertEqual(state(path), ("Work", 1500, False))
            self.assertEqual(state(path, "toggle"), ("Work", 1500, True))
        with patch("time.monotonic", return_value=101.5):
            self.assertEqual(state(path, "toggle"), ("Work", 1499, False))
        with patch("time.monotonic", return_value=201):
            self.assertEqual(state(path), ("Work", 1499, False))
            self.assertEqual(state(path, "toggle"), ("Work", 1499, True))
        with patch("time.monotonic", return_value=1700), patch("subprocess.Popen") as notify:
            self.assertEqual(state(path), ("Break", 300, True))
            self.assertEqual(state(path), ("Break", 300, True))
            notify.assert_called_once_with(["notify-send", "Pomodoro", "Break time"])
            self.assertEqual(state(path, "reset"), ("Work", 1500, False))
            self.assertEqual(json.loads(path.read_text()), [0, 1500, None])
