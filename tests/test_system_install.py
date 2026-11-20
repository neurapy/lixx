import importlib.util
import io
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
loader = SourceFileLoader("lixx", str(REPO / "lixx"))
lixx = importlib.util.module_from_spec(importlib.util.spec_from_loader("lixx", loader))
loader.exec_module(lixx)


class SystemInstallTests(unittest.TestCase):
    def setUp(self):
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.checkout = root / "checkout"
        self.home = root / "account"
        self.apt = root / "etc/apt"
        self.log = root / "apt-log"
        bin_dir = root / "bin"
        for path in (self.home, bin_dir, self.apt / "preferences.d", self.apt / "sources.list.d"):
            path.mkdir(parents=True)
        shutil.copytree(REPO / lixx.PROFILE, self.checkout / lixx.PROFILE)
        assets = self.checkout / "static_assets/home"
        assets.mkdir(parents=True)
        (assets / "desktop-file").write_text("installed\n")
        # No subprocess in these tests can elevate privileges or contact APT.
        (bin_dir / "sudo").write_text('#!/bin/sh\nexec "$@"\n')
        (bin_dir / "apt-get").write_text(
            '#!/usr/bin/python3\nimport json, os, sys\n'
            'with open(os.environ["TEST_APT_LOG"], "a") as log:\n'
            '    print(json.dumps(sys.argv[1:]), file=log)\n'
            'if "indextargets" in sys.argv:\n'
            '    if any(arg.startswith("Dir::Etc::sourcelist=") for arg in sys.argv):\n'
            '        print("https://example.invalid/dists/resolute/main/binary-amd64/Packages profile.sources:1")\n'
            '    else:\n'
            '        print(os.environ.get("TEST_INDEX", ""))\n'
            'if os.environ.get("TEST_FAIL") in sys.argv:\n'
            '    sys.exit(100)\n'
        )
        for stub in bin_dir.iterdir():
            stub.chmod(0o755)
        self.enterContext(patch.dict(os.environ, {
            "HOME": str(self.home), "PATH": str(bin_dir) + ":" + os.defpath,
            "TEST_APT_LOG": str(self.log),
        }, clear=True))
        self.enterContext(patch.object(lixx, "__file__", str(self.checkout / "lixx")))
        self.enterContext(patch.object(lixx, "APT_DIR", self.apt))
        self.enterContext(patch.object(lixx.platform, "freedesktop_os_release",
                                           return_value={"ID": "ubuntu", "VERSION_ID": "26.04"}))
        self.enterContext(patch.object(lixx.os, "geteuid", return_value=1000))
        (bin_dir / "dpkg").write_text("#!/bin/sh\necho amd64\n")
        (bin_dir / "dpkg").chmod(0o755)
        self.output = io.TextIOWrapper(io.BytesIO(), write_through=True)
        self.enterContext(redirect_stdout(self.output))
        self.pref = self.apt / "preferences.d/lixx-hyprland.pref"
        self.source = self.apt / "sources.list.d/lixx-hyprland.sources"
        self.home_file = self.home / "desktop-file"

    def apt_calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_clean_install_and_rerun(self):
        completed = []
        lixx.run("install", completed)
        self.assertEqual(completed, [self.pref, self.source, self.home_file])
        profile = self.checkout / lixx.PROFILE
        for file in (self.pref, self.source):
            self.assertEqual(file.read_bytes(), (profile / "etc/apt" / file.relative_to(self.apt)).read_bytes())
            self.assertEqual(file.stat().st_mode & 0o777, 0o644)
        self.assertEqual(self.apt_calls()[-2:], [
            ["--error-on=any", "update"],
            ["--no-remove", "--no-install-recommends", "satisfy", *lixx.package_requirements(profile)],
        ])
        before = [file.stat().st_ino for file in completed]
        second = []
        lixx.run("install", second)
        self.assertEqual(second, [])
        self.assertEqual([file.stat().st_ino for file in completed], before)

    def test_review_cancel_preserves_system_and_home(self):
        self.source.write_text("locally edited source\n")
        self.home_file.write_text("locally edited config\n")
        with patch("builtins.input", side_effect=["yes", "cancel"]), self.assertRaises(lixx.Cancelled):
            lixx.run("install", [])
        self.assertFalse(self.pref.exists())
        self.assertFalse(self.log.exists())
        self.assertEqual(self.source.read_text(), "locally edited source\n")
        self.assertEqual(self.home_file.read_text(), "locally edited config\n")

    def test_discovers_new_preferences_and_limits_system_paths(self):
        profile = self.checkout / lixx.PROFILE / "etc/apt"
        extra = Path("preferences.d/another.pref")
        (profile / extra).write_text("Package: example\nPin: version *\nPin-Priority: 100\n")
        (profile / extra).chmod(0o755)
        (profile / "apt.conf").write_text("local configuration")
        with self.assertRaisesRegex(lixx.InstallError, "Unexpected APT profile file"):
            lixx.run("install", [])
        self.assertFalse((self.apt / extra).exists())
        (profile / "apt.conf").unlink()
        lixx.run("install", [])
        self.assertEqual((self.apt / extra).read_bytes(), (profile / extra).read_bytes())
        self.assertEqual((self.apt / extra).stat().st_mode & 0o777, 0o644)
        repeated = []
        lixx.run("install", repeated)
        self.assertEqual(repeated, [])

    def test_failed_apt_and_retry_with_existing_ppa(self):
        os.environ["TEST_INDEX"] = ("https://example.invalid/dists/resolute/main/binary-amd64/Packages "
                                    "/etc/apt/sources.list.d/local.sources:1")
        os.environ["TEST_FAIL"] = "update"
        completed = []
        with self.assertRaises(subprocess.CalledProcessError):
            lixx.run("install", completed)
        self.assertEqual(completed, [self.pref])
        self.assertFalse(self.source.exists())
        self.assertFalse(self.home_file.exists())
        self.assertFalse(any("satisfy" in call for call in self.apt_calls()))
        del os.environ["TEST_FAIL"]
        lixx.run("install", completed)
        self.assertEqual(completed, [self.pref, self.home_file])

    def test_unsupported_system_or_root_stops_before_staging(self):
        for release, uid in (({"ID": "ubuntu", "VERSION_ID": "24.04"}, 1000),
                             ({"ID": "ubuntu", "VERSION_ID": "26.04"}, 0)):
            with self.subTest(release=release, uid=uid), \
                 patch.object(lixx.platform, "freedesktop_os_release", return_value=release), \
                 patch.object(lixx.os, "geteuid", return_value=uid), self.assertRaises(lixx.InstallError):
                lixx.run("install", [])
        self.assertFalse((self.checkout / "tree").exists())
        self.assertFalse(self.log.exists())
