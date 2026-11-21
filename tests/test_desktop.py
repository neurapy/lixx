import configparser
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


HOME_TREE = Path(__file__).resolve().parents[1] / "targets/all/trees/home"
BIN = HOME_TREE / ".local/share/lixx-system/bin"


class DesktopTests(unittest.TestCase):
    def test_molten_reuses_an_existing_environment_offline(self):
        with tempfile.TemporaryDirectory() as tmp:
            data = Path(tmp) / "editor data"
            venv = data / "work-nvim/molten-venv"
            subprocess.run([sys.executable, "-m", "venv", "--without-pip", venv], check=True)
            modules = Path(tmp) / "modules"
            modules.mkdir()
            for name in ("pynvim", "jupyter_client", "ipykernel", "nbformat"):
                (modules / f"{name}.py").touch()
            jupyter = Path(tmp) / "jupyter data"
            env = {**os.environ, "XDG_DATA_HOME": str(data), "NVIM_APPNAME": "work-nvim",
                   "JUPYTER_DATA_DIR": str(jupyter), "PYTHONPATH": str(modules), "PIP_NO_INDEX": "1"}
            result = subprocess.run([HOME_TREE / ".config/nvim/bin/molten-python", "-c",
                                     "import sys; print(sys.executable)"], env=env,
                                    text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout.strip(), str(venv / "bin/python"))
            self.assertEqual((jupyter / "runtime").stat().st_mode & 0o777, 0o700)
            self.assertFalse((venv / "bin/pip").exists())

    def test_bluetooth_audio_is_started_at_login_and_on_hotplug(self):
        units = HOME_TREE / ".config/systemd/user"
        for trigger in ("wireplumber.service", "bluetooth.target"):
            with self.subTest(trigger=trigger):
                wants = set()
                for path in (units / f"{trigger}.d").glob("*.conf"):
                    fragment = configparser.ConfigParser()
                    fragment.read(path)
                    wants.update(fragment.get("Unit", "Wants", fallback="").split())
                self.assertIn("wireplumber@bluetooth.service", wants)

    def test_locker_runs_after_a_layout_error_and_returns_its_status(self):
        runtime = Path(self.enterContext(tempfile.TemporaryDirectory()))
        systemctl = runtime / "systemctl"
        systemctl.write_text('#!/bin/sh\necho "$@" > "$XDG_RUNTIME_DIR/lock-service"\nexit 1\n')
        systemctl.chmod(0o755)
        for name, status in {"hyprctl": 1, "busctl": 1, "pgrep": 1, "hyprlock": 37}.items():
            command = runtime / name
            command.write_text(f"#!/bin/sh\nexit {status}\n")
            command.chmod(0o755)
        env = {**os.environ, "PATH": f"{runtime}:/usr/bin", "XDG_RUNTIME_DIR": str(runtime)}
        self.assertNotEqual(subprocess.run([BIN / "lixx-lock"], env=env).returncode, 0)
        self.assertEqual((runtime / "lock-service").read_text().strip(), "--user start --wait lixx-lock.service")
        result = subprocess.run([BIN / "lixx-lock", "--session"], stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, env=env)
        self.assertEqual(result.returncode, 37)

    def test_swaync_discovers_backlights_and_keeps_other_widgets(self):
        select = runpy.run_path(str(BIN / "lixx-swaync-config"))["configure_backlights"]
        devices = Path(self.enterContext(tempfile.TemporaryDirectory()))

        def settings():
            return {"widgets": ["volume", "backlight", "notifications"], "widget-config": {"backlight": {"label": "Light"}}}

        config = settings()
        select(config, devices)
        self.assertEqual(config["widgets"], ["volume", "notifications"])
        for name in ("amdgpu_bl0", "intel_backlight"):
            device = devices / "backlight" / name
            device.mkdir(parents=True)
            (device / "brightness").touch()
            (device / "max_brightness").touch()
            config = settings()
            select(config, devices)
            self.assertIn("backlight", config["widgets"])
            self.assertEqual(config["widget-config"]["backlight"].get("device", "intel_backlight"), name)
        config["widget-config"]["backlight"]["device"] = "amdgpu_bl0"
        select(config, devices)
        self.assertEqual(config["widget-config"]["backlight"]["device"], "amdgpu_bl0")

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
