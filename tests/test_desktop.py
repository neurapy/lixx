import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


BIN = Path(__file__).resolve().parents[1] / "targets/all/trees/home/.local/share/lixx-system/bin"


class DesktopTests(unittest.TestCase):
    def test_waybar_toggle_uses_the_existing_service(self):
        unit = "lixx-waybar.service"
        for status, action in ((0, "stop"), (3, "start")):
            with self.subTest(action=action), patch("sys.argv", ["lixx-waybar", "toggle"]), \
                 patch("subprocess.run", return_value=subprocess.CompletedProcess([], status)) as query, \
                 patch("os.execlp", side_effect=SystemExit) as execute, self.assertRaises(SystemExit):
                runpy.run_path(str(BIN / "lixx-waybar"), run_name="__main__")
            query.assert_called_once_with(["systemctl", "--user", "is-active", "--quiet", unit])
            execute.assert_called_once_with("systemctl", "systemctl", "--user", action, unit)

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

    def test_capture_accepts_an_empty_special_workspace(self):
        rectangles = runpy.run_path(str(BIN / "lixx-capture"))["window_rectangles"]
        monitors = [{"activeWorkspace": {"id": 3}, "specialWorkspace": {"name": ""}}]
        window = {"at": [-12, 8], "size": [768, 512], "mapped": True, "workspace": {"id": 3}}
        offscreen = {**window, "workspace": {"id": 1}}
        self.assertEqual(rectangles([window, offscreen, {**window, "mapped": False}], monitors),
                         ["-12,8 768x512"])
        self.assertEqual(rectangles([{**offscreen, "pinned": True}], monitors), ["-12,8 768x512"])

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
