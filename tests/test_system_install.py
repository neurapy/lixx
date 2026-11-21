import hashlib
import importlib.util
import io
import json
import os
import shutil
import socket
import subprocess
import tarfile
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


def write_file(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class SystemInstallTests(unittest.TestCase):
    def setUp(self):
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.checkout = root / "checkout"
        self.home = root / "account"
        self.system = root / "system"
        self.apt = self.system / "etc/apt"
        self.log = root / "apt-log"
        bin_dir = root / "bin"
        for path in (self.home, bin_dir, self.apt / "preferences.d", self.apt / "sources.list.d"):
            path.mkdir(parents=True)
        self.profile = self.checkout / lixx.PROFILE
        self.target_tree = self.profile / "tree"
        self.shared = self.checkout / "targets/all/trees"
        shutil.copytree(REPO / lixx.PROFILE / "tree/root", self.target_tree / "root")
        shutil.copy2(REPO / lixx.PROFILE / "packages.txt", self.profile)
        (self.shared / "home").mkdir(parents=True)
        (self.shared / "home/desktop-file").write_text("installed\n")
        # No subprocess in these tests can elevate privileges or contact APT.
        (bin_dir / "sudo").write_text('#!/bin/sh\nexec "$@"\n')
        (bin_dir / "apt-get").write_text(
            '#!/usr/bin/python3\nimport json, os, sys\n'
            'with open(os.environ["TEST_APT_LOG"], "a") as log:\n'
            '    print(json.dumps(sys.argv[1:]), file=log)\n'
            'if "--with-source" in sys.argv:\n'
            '    archive = sys.argv[sys.argv.index("--with-source") + 1]\n'
            '    assert os.stat(archive).st_mode & 0o004 and os.stat(os.path.dirname(archive)).st_mode & 0o001\n'
            'if "indextargets" in sys.argv:\n'
            '    if any(arg.startswith("Dir::Etc::sourcelist=") for arg in sys.argv):\n'
            '        suite = "sid" if any("lixx-neovim.sources" in a for a in sys.argv) else "resolute"\n'
            '        print(f"https://example.invalid/dists/{suite}/main/binary-amd64/Packages profile.sources:1")\n'
            '    else:\n'
            '        print(os.environ.get("TEST_INDEX", ""))\n'
            'if os.environ.get("TEST_FAIL") in sys.argv:\n'
            '    sys.exit(100)\n'
        )
        (bin_dir / "apt-cache").write_text(
            '#!/bin/sh\n[ "$*" = "policy neovim" ] || exit 1\n'
            'printf "neovim:\\n  Installed: 0.12.6-1\\n  Candidate: %s\\n" "${TEST_NVIM_CANDIDATE:-0.12.7-1}"\n'
        )
        for stub in bin_dir.iterdir():
            stub.chmod(0o755)
        self.enterContext(patch.dict(os.environ, {
            "HOME": str(self.home), "PATH": str(bin_dir) + ":" + os.defpath,
            "TEST_APT_LOG": str(self.log),
        }, clear=True))
        self.enterContext(patch.object(lixx, "__file__", str(self.checkout / "lixx")))
        self.enterContext(patch.object(lixx, "SYSTEM_ROOT", self.system))
        self.enterContext(patch.object(lixx.platform, "freedesktop_os_release",
                                           return_value={"ID": "ubuntu", "VERSION_ID": "26.04"}))
        self.enterContext(patch.object(lixx.os, "geteuid", return_value=1000))
        (bin_dir / "dpkg").write_text("#!/bin/sh\necho amd64\n")
        (bin_dir / "dpkg").chmod(0o755)
        self.output = io.TextIOWrapper(io.BytesIO(), write_through=True)
        self.enterContext(redirect_stdout(self.output))
        self.pref = self.apt / "preferences.d/lixx-hyprland.pref"
        self.source = self.apt / "sources.list.d/lixx-hyprland.sources"
        self.editor_pref = self.apt / "preferences.d/lixx-neovim.pref"
        self.editor_source = self.apt / "sources.list.d/lixx-neovim.sources"
        self.polkit_dropin = self.system / "etc/systemd/user/hyprpolkitagent.service.d/20-lixx.conf"
        self.home_file = self.home / "desktop-file"

    def test_release_program_uses_reviewed_bytes_and_required_executable_mode(self):
        cache = self.checkout / "tree/downloads"
        cache.mkdir(parents=True)
        tar_path = cache / "release"
        body = b"#!/bin/sh\necho works\n"
        with tarfile.open(tar_path, "w:gz") as archive:
            entry = tarfile.TarInfo("program")
            entry.size = len(body)
            entry.mode = 0o644
            archive.addfile(entry, io.BytesIO(body))
        digest = hashlib.sha256(tar_path.read_bytes()).hexdigest()
        tar_path.rename(cache / digest)
        (self.profile / "archives.toml").write_text(
            f'[[archive]]\nurl="https://example.invalid/release"\nsha256="{digest}"\n'
            'member="program"\ndestination=".local/bin/program"\nexecutable=true\n'
        )
        lixx.install([])
        out = self.home / ".local/bin/program"
        self.assertEqual(subprocess.check_output([out], text=True), "works\n")
        out.write_text("local edit")
        with patch("builtins.input", return_value="skip"):
            lixx.install([])
        self.assertEqual(out.read_text(), "local edit")

    def apt_calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_clean_install_and_rerun(self):
        runtime = Path(self.enterContext(tempfile.TemporaryDirectory()))
        bus = self.enterContext(socket.socket(socket.AF_UNIX))
        bus.bind(str(runtime / "bus"))
        os.environ["XDG_RUNTIME_DIR"] = str(runtime)
        os.environ["PATH"] = str(runtime) + ":" + os.environ["PATH"]
        systemctl = runtime / "systemctl"
        systemctl.write_text('#!/bin/sh\necho "$@" >> "$XDG_RUNTIME_DIR/reloads"\n')
        systemctl.chmod(0o755)
        completed = []
        lixx.install(completed)
        self.assertEqual(completed, [self.pref, self.editor_pref, self.source, self.editor_source,
                                     self.polkit_dropin, self.home_file])
        for file in (self.pref, self.editor_pref, self.source, self.editor_source, self.polkit_dropin):
            source = self.target_tree / "root" / file.relative_to(self.system)
            self.assertEqual(file.read_bytes(), source.read_bytes())
            self.assertEqual(file.stat().st_mode & 0o777, 0o644)
        self.assertEqual(self.apt_calls()[-2:], [
            ["--error-on=any", "update"],
            ["--no-remove", "--no-install-recommends", "satisfy", *lixx.package_requirements(self.profile),
             "neovim (= 0.12.7-1)"],
        ])
        before = [file.stat().st_ino for file in completed]
        second = []
        os.environ["TEST_NVIM_CANDIDATE"] = "0.13.0-1"
        lixx.install(second)
        self.assertIn("neovim (= 0.13.0-1)", self.apt_calls()[-1])
        self.assertEqual(second, [])
        self.assertEqual([file.stat().st_ino for file in completed], before)
        self.assertEqual((runtime / "reloads").read_text().splitlines(), ["--user daemon-reload"])

    @unittest.skipUnless(shutil.which("systemd-analyze"), "requires systemd-analyze")
    def test_gdm_skips_the_hyprland_polkit_agent(self):
        units = self.target_tree / "root/etc/systemd/user"
        agent = "hyprpolkitagent.service"
        # Reproduce the packaged Wayland condition alongside the real Ubuntu drop-in.
        write_file(units / agent,
                   "[Unit]\nConditionEnvironment=WAYLAND_DISPLAY\n[Service]\nExecStart=/bin/true\n")
        env = {**os.environ, "SYSTEMD_UNIT_PATH": str(units), "XDG_RUNTIME_DIR": str(self.home),
               "WAYLAND_DISPLAY": "wayland-0"}
        for desktop, extra, status in (("GNOME-Greeter:GNOME", {}, 1),
                                       ("Hyprland", {"HYPRLAND_INSTANCE_SIGNATURE": "test"}, 0)):
            with self.subTest(desktop=desktop):
                result = subprocess.run(
                    ["systemd-analyze", "--user", "--generators=no", f"--unit={agent}", "condition"],
                    env={**env, "XDG_CURRENT_DESKTOP": desktop, **extra}, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, status, result.stderr)

    def test_review_cancel_preserves_system_and_home(self):
        self.source.write_text("locally edited source\n")
        self.home_file.write_text("locally edited config\n")
        with patch("builtins.input", side_effect=["yes", "cancel"]), self.assertRaises(lixx.Cancelled):
            lixx.install([])
        self.assertFalse(self.pref.exists())
        self.assertTrue(all("indextargets" in call for call in self.apt_calls()))
        self.assertEqual(self.source.read_text(), "locally edited source\n")
        self.assertEqual(self.home_file.read_text(), "locally edited config\n")

    def test_verified_debs_are_offered_to_the_same_apt_transaction(self):
        manifest = self.profile / "packages.sha256"
        shutil.copy2(REPO / lixx.PROFILE / manifest.name, manifest)
        helper = self.home / "apt-helper"
        helper.write_text('#!/bin/sh\nprintf "%s\\t%s\\t%s\\t%s\\n" "$@" >> "$HOME/download"\n(umask 077 && touch "$3")\n')
        helper.chmod(0o755)
        with patch.object(lixx, "APT_HELPER", helper):
            lixx.install([])
        downloads = (self.home / "download").read_text().splitlines()
        entries = [line.split() for line in manifest.read_text().splitlines() if line and not line.startswith("#")]
        sources = []
        for (digest, url), download in zip(entries, downloads, strict=True):
            command, uri, archive, checksum = download.split("\t")
            self.assertEqual((command, uri, checksum), ("download-file", url, f"SHA256:{digest}"))
            self.assertEqual(Path(archive).name, url.rsplit("/", 1)[1])
            self.assertFalse(Path(archive).parent.exists())
            sources.extend(["--with-source", archive])
        self.assertEqual(self.apt_calls()[-1], [
            "--no-remove", "--no-install-recommends", *sources, "satisfy",
            *lixx.package_requirements(self.profile), "neovim (= 0.12.7-1)",
        ])

    def test_missing_neovim_candidate_stops_before_install(self):
        os.environ["TEST_NVIM_CANDIDATE"] = "(none)"
        with self.assertRaisesRegex(lixx.InstallError, "no Neovim candidate"):
            lixx.install([])
        self.assertFalse(any("satisfy" in call for call in self.apt_calls()))
        self.assertFalse(self.home_file.exists())

    def test_debian_index_only_offers_the_editor_and_its_release_versions(self):
        apt_cache = shutil.which("apt-cache", path=os.defpath)
        release = Path("/etc/os-release")
        if not apt_cache or not release.is_file() or 'VERSION_ID="26.04"' not in release.read_text():
            self.skipTest("requires Ubuntu 26.04 APT")
        lists = self.home / "lists"
        lists.mkdir()
        index = "deb.debian.org_debian_dists_sid"
        (lists / f"{index}_Release").write_text(
            "Origin: Debian\nSuite: unstable\nCodename: sid\nArchitectures: amd64\nComponents: main\n"
        )
        names = ("neovim", "neovim-runtime", "libtree-sitter0.26", "libc6", "tree-sitter-cli")
        records = [(name, "1.2.3-1") for name in names]
        records.extend([("neovim", "1.3.0~rc1-1"), ("neovim", "1.4.0+git1-1")])
        (lists / f"{index}_main_binary-amd64_Packages").write_text("".join(
            f"Package: {name}\nVersion: {version}\nArchitecture: amd64\nDescription: fixture\n\n"
            for name, version in records
        ))
        apt = self.target_tree / "root/etc/apt"
        result = subprocess.run([
            apt_cache, "-o", f"Dir::State::lists={lists}", "-o", "Dir::State::status=/dev/null",
            "-o", "Dir::Cache::pkgcache=", "-o", f"Dir::Etc::sourcelist={apt}/sources.list.d/lixx-neovim.sources",
            "-o", "Dir::Etc::sourceparts=-", "-o", f"Dir::Etc::preferences={apt}/preferences.d/lixx-neovim.pref",
            "-o", "Dir::Etc::preferencesparts=-", "policy", *names,
        ], text=True, capture_output=True, check=True, env={**os.environ, "LC_ALL": "C"})
        self.assertEqual(result.stdout.count("Candidate: 1.2.3-1"), 3, result.stdout)
        for name in names[:3]:
            self.assertIn(f"{name}:\n", result.stdout)
        for name in names[3:]:
            self.assertNotIn(f"{name}:\n", result.stdout)
        self.assertIn("1.3.0~rc1-1 -1", result.stdout)
        self.assertIn("1.4.0+git1-1 -1", result.stdout)

    def test_failed_package_download_stops_before_package_install(self):
        shutil.copy2(REPO / lixx.PROFILE / "packages.sha256", self.profile)
        with patch.object(lixx, "APT_HELPER", "/bin/false"), self.assertRaises(subprocess.CalledProcessError):
            lixx.install([])
        self.assertFalse(any("satisfy" in call for call in self.apt_calls()))
        self.assertFalse(self.home_file.exists())

    @unittest.skipUnless(shutil.which("systemd-analyze") and
                         Path("/usr/lib/systemd/user/org.freedesktop.IBus.session.GNOME.service").is_file(),
                         "requires Ubuntu's IBus units and systemd-analyze")
    def test_ibus_units_load_in_either_order(self):
        units = self.home / "units"
        units.mkdir()
        generic = "org.freedesktop.IBus.session.generic.service"
        gnome = "org.freedesktop.IBus.session.GNOME.service"
        shutil.copy(REPO / lixx.PROFILE / "tree/home/.config/systemd/user" / generic, units)
        shutil.copy(Path("/usr/lib/systemd/user") / gnome, units)
        shutil.copytree(REPO / "targets/all/trees/home/.config/systemd/user" / (generic + ".d"),
                        units / (generic + ".d"))
        env = {**os.environ, "SYSTEMD_UNIT_PATH": f"{units}:", "XDG_RUNTIME_DIR": str(self.home)}
        for order in ((generic, gnome), (gnome, generic)):
            result = subprocess.run(["systemd-analyze", "--user", "--generators=no", "--man=no",
                                     "verify", *order], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_home_overlay_merges_directories_and_reviews_only_the_winner(self):
        config = Path("home/.config/example")
        write_file(self.shared / config / "shared", "for everyone")
        write_file(self.target_tree / config / "extra", "for Ubuntu")
        write_file(self.target_tree / "home/desktop-file", "Ubuntu override\n")
        write_file(self.target_tree / "root/etc/target-only", "system file")
        self.home_file.write_text("local edit\n")
        with patch("builtins.input", return_value="yes") as prompt:
            lixx.install([])
        prompt.assert_called_once()
        self.assertIn(b"-local edit\n+Ubuntu override", self.output.buffer.getvalue())
        self.assertNotIn(b"+installed\n", self.output.buffer.getvalue())
        self.assertEqual(self.home_file.read_text(), "Ubuntu override\n")
        self.assertEqual((self.home / ".config/example/shared").read_text(), "for everyone")
        self.assertEqual((self.home / ".config/example/extra").read_text(), "for Ubuntu")
        self.assertEqual((self.system / "etc/target-only").read_text(), "system file")
        self.assertTrue(any("satisfy" in call for call in self.apt_calls()))
        repeated = []
        lixx.install(repeated)
        self.assertEqual(repeated, [])

    def test_root_overlay_installs_shared_files_target_overrides_and_executables(self):
        command = Path("usr/local/bin/example")
        write_file(self.shared / "root" / command, "shared")
        override = self.target_tree / "root" / command
        write_file(override, "Ubuntu")
        override.chmod(0o755)
        write_file(self.shared / "root/etc/example/defaults", "shared defaults")
        write_file(self.shared / "root" / self.pref.relative_to(self.system), "shared preference")
        write_file(self.shared / "root/.gitkeep", "")
        lixx.install([])
        self.assertEqual((self.system / command).read_text(), "Ubuntu")
        self.assertEqual((self.system / command).stat().st_mode & 0o777, 0o755)
        self.assertFalse((self.system / command).samefile(override))
        self.assertEqual((self.system / "etc/example/defaults").read_text(), "shared defaults")
        target_pref = self.target_tree / "root" / self.pref.relative_to(self.system)
        self.assertEqual(self.pref.read_bytes(), target_pref.read_bytes())
        self.assertFalse((self.system / ".gitkeep").exists())
        repeated = []
        lixx.install(repeated)
        self.assertEqual(repeated, [])

    def test_package_created_root_config_gets_a_diff_before_replacement(self):
        relative = Path("etc/example.conf")
        write_file(self.shared / "root" / relative, "desktop config\n")
        destination = self.system / relative
        with patch.object(lixx, "install_packages",
                          side_effect=lambda *_: destination.write_text("package default\n")), \
             patch("builtins.input", return_value="skip") as prompt:
            lixx.install([])
        prompt.assert_called_once()
        self.assertIn(b"-package default\n+desktop config", self.output.buffer.getvalue())
        self.assertEqual(destination.read_text(), "package default\n")
        self.assertTrue(self.home_file.exists())

    def test_file_directory_collision_fails_before_install(self):
        (self.target_tree / "home/desktop-file").mkdir(parents=True)
        with self.assertRaisesRegex(lixx.InstallError, "both a file and a directory: home/desktop-file"):
            lixx.install([])
        self.assertFalse(self.home_file.exists())
        self.assertFalse(self.pref.exists())
        self.assertFalse(self.log.exists())

    def test_target_tree_symlink_is_rejected(self):
        (self.target_tree / "home").symlink_to(self.shared / "home")
        with self.assertRaisesRegex(lixx.InstallError, "symlink"):
            lixx.install([])
        self.assertFalse(self.home_file.exists())

    def test_system_destination_inside_checkout_is_rejected_before_rebuilding_home(self):
        previous = self.checkout / "tree/home/keep"
        write_file(previous, "keep")
        write_file(self.shared / "root/checkout/tree/home/keep", "incoming")
        with patch.object(lixx, "SYSTEM_ROOT", self.checkout.parent), \
             self.assertRaisesRegex(lixx.InstallError, "Destination points into the checkout"):
            lixx.install([])
        self.assertEqual(previous.read_text(), "keep")
        self.assertFalse(self.log.exists())

    def test_changed_root_payload_is_discarded(self):
        relative = Path("etc/example.conf")
        write_file(self.shared / "root" / relative, "approved")
        staged = self.checkout / "tree/root" / relative
        with patch.object(lixx, "install_packages", side_effect=lambda *_: staged.write_text("changed")), \
             self.assertRaisesRegex(lixx.InstallError, "Staged file changed"):
            lixx.install([])
        self.assertFalse((self.system / relative).exists())
        self.assertEqual(list(self.system.rglob(".lixx-*")), [])

    def test_discovers_new_preferences_and_limits_system_paths(self):
        profile = self.target_tree / "root/etc/apt"
        extra = Path("preferences.d/another.pref")
        (profile / extra).write_text("Package: example\nPin: version *\nPin-Priority: 100\n")
        (profile / extra).chmod(0o755)
        (profile / "apt.conf").write_text("local configuration")
        with self.assertRaisesRegex(lixx.InstallError, "Unexpected APT profile file"):
            lixx.install([])
        self.assertFalse((self.apt / extra).exists())
        (profile / "apt.conf").unlink()
        lixx.install([])
        self.assertEqual((self.apt / extra).read_bytes(), (profile / extra).read_bytes())
        self.assertEqual((self.apt / extra).stat().st_mode & 0o777, 0o644)
        repeated = []
        lixx.install(repeated)
        self.assertEqual(repeated, [])

    def test_failed_apt_and_retry_with_existing_ppa(self):
        os.environ["TEST_INDEX"] = ("https://example.invalid/dists/resolute/main/binary-amd64/Packages "
                                    "/etc/apt/sources.list.d/local.sources:1")
        os.environ["TEST_FAIL"] = "update"
        completed = []
        with self.assertRaises(subprocess.CalledProcessError):
            lixx.install(completed)
        self.assertEqual(completed, [self.pref, self.editor_pref, self.editor_source])
        self.assertFalse(self.source.exists())
        self.assertFalse(self.home_file.exists())
        self.assertFalse(any("satisfy" in call for call in self.apt_calls()))
        del os.environ["TEST_FAIL"]
        lixx.install(completed)
        self.assertEqual(completed, [self.pref, self.editor_pref, self.editor_source,
                                     self.polkit_dropin, self.home_file])

    def test_unsupported_system_or_root_stops_before_staging(self):
        for release, uid in (({"ID": "debian", "VERSION_ID": "13"}, 1000),
                             ({"ID": "ubuntu", "VERSION_ID": "24.04"}, 1000),
                             ({"ID": "ubuntu", "VERSION_ID": "26.04"}, 0)):
            with self.subTest(release=release, uid=uid), \
                 patch.object(lixx.platform, "freedesktop_os_release", return_value=release), \
                 patch.object(lixx.os, "geteuid", return_value=uid), self.assertRaises(lixx.InstallError):
                lixx.install([])
        self.assertFalse((self.checkout / "tree").exists())
        self.assertFalse(self.home_file.exists())
        self.assertFalse(self.log.exists())
