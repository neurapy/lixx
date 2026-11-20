import hashlib
from pathlib import Path
import runpy
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch


vm = runpy.run_path(str(Path(__file__).resolve().parents[1] / "vm/run"))


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(tempfile.TemporaryDirectory()))

    def test_snapshot_uses_working_files_and_omits_deleted_and_ignored_files(self):
        checkout = self.root / "working copy"
        subprocess.run(["git", "init", "-q", checkout], check=True)
        (checkout / ".gitignore").write_text("/tree/\n/vm/.local/\n")
        for name in ("changed", "deleted"):
            (checkout / name).write_text("original")
        subprocess.run(["git", "add", "."], cwd=checkout, check=True)
        (checkout / "changed").write_text("edited")
        (checkout / "deleted").unlink()
        (checkout / "new helper").write_text("new")
        (checkout / "new helper").chmod(0o755)
        (checkout / "tree").mkdir()
        (checkout / "tree/stale").touch()
        state = checkout / "vm/.local"
        (state / "images").mkdir(parents=True)
        (state / "images/base.qcow2").touch()
        # Even an inadvertently staged local file must stay out of the VM seed.
        (state / "guest-key").touch()
        subprocess.run(["git", "add", "-f", "vm/.local/guest-key"], cwd=checkout, check=True)
        (checkout / "link").symlink_to(self.root / "outside")
        archive = self.root / "checkout.tar"
        vm["snapshot"](checkout, archive)
        with tarfile.open(archive) as result:
            self.assertEqual(set(result.getnames()), {".gitignore", "changed", "new helper", "link"})
            self.assertEqual(result.extractfile("changed").read(), b"edited")
            self.assertEqual(result.extractfile("new helper").read(), b"new")
            self.assertTrue(result.getmember("new helper").mode & 0o100)
            self.assertTrue(result.getmember("link").issym())

    def test_only_a_verified_base_is_reused_or_published(self):
        self.enterContext(patch("builtins.print"))
        contents = b"pristine"
        checksum = hashlib.sha256(contents).hexdigest()
        profile = {"image": "https://example.test/base.img", "sha256": checksum}
        state = self.root / "vm/.local"
        cached = state / "images" / (checksum + ".qcow2")

        def download(args, *, check):
            Path(args[args.index("--output") + 1]).write_bytes(response)

        with patch("subprocess.run", side_effect=download) as fetch:
            response = b"partial download"
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                vm["base_image"](profile, state)
            self.assertFalse(cached.exists())
            cached.write_bytes(b"corrupt cache")
            response = contents
            self.assertEqual(vm["base_image"](profile, state), cached)
            self.assertEqual(cached.read_bytes(), contents)
            self.assertEqual(vm["base_image"](profile, state), cached)
            self.assertEqual(fetch.call_count, 2)

    def test_closing_early_and_guest_failures_are_reported(self):
        console = self.root / "console.log"
        for messages, error in ((b"booting\r\n", "closed before"),
                                (b"LIXX_INSTALL_EXIT=1\r\n", "install exited with status 1"),
                                (b"LIXX_INSTALL_EXIT=0\r\nLIXX_DESKTOP_EXIT=7\r\n", "desktop exited with status 7")):
            with self.subTest(error=error):
                console.write_bytes(messages)
                with self.assertRaisesRegex(ValueError, error):
                    vm["check_guest_status"](console)
        console.write_bytes(b"LIXX_INSTALL_EXIT=0\r\n")
        vm["check_guest_status"](console)
