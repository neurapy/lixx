import hashlib
import os
import pty
import select
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import unittest
from contextlib import contextmanager
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
SHARED_HOME = Path("targets/all/trees/home")
OPTIONS = Path(".config/zsh/options.zsh")
PROMPT = b"Replace? [yes/skip/cancel] "


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.checkout = self.root / "checkout"
        self.home = self.root / "account"
        self.home.mkdir()
        self.checkout.mkdir()
        shutil.copy2(REPO / "lixx", self.checkout)
        self.assets = self.checkout / SHARED_HOME
        (self.assets / OPTIONS).parent.mkdir(parents=True)
        shutil.copy2(REPO / SHARED_HOME / OPTIONS, self.assets / OPTIONS)
        self.target = self.home / OPTIONS
        self.env = {
            "HOME": str(self.home), "PATH": os.defpath, "LC_ALL": "C",
            "TERM": "xterm-256color", "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
        }

    def cli(self, command="update", answers="", *, umask=0o022):
        return subprocess.run(
            [self.checkout / "lixx", command], input=answers, text=True,
            capture_output=True, cwd=self.root, env=self.env, timeout=10, umask=umask,
        )

    @contextmanager
    def live_update(self, checkout=None, env=None):
        with subprocess.Popen(
            [(checkout or self.checkout) / "lixx", "update"], cwd=self.root,
            env=env or self.env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, bufsize=0,
        ) as process:
            try:
                yield process
            finally:
                if process.poll() is None:
                    process.kill()

    def prompt(self, process):
        output = bytearray()
        deadline = time.monotonic() + 5
        while PROMPT not in output:
            timeout = max(0, deadline - time.monotonic())
            if not select.select([process.stdout], [], [], timeout)[0]:
                self.fail(f"Timed out waiting for review: {output!r}")
            chunk = os.read(process.stdout.fileno(), 8192)
            if not chunk:
                self.fail(f"CLI exited before review: {output!r}")
            output.extend(chunk)
        return bytes(output)

    def test_new_install_staging_and_idempotent_update(self):
        result = self.cli(umask=0o027)
        self.assertEqual(result.returncode, 0, result.stderr)
        staged = self.checkout / "tree/home" / OPTIONS
        for source in (self.assets / OPTIONS, staged):
            self.assertEqual(source.read_bytes(), self.target.read_bytes())
            self.assertFalse(source.samefile(self.target))
        self.assertFalse(self.target.is_symlink())
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o640)

        self.target.chmod(0o600)
        os.utime(self.target, ns=(1234567890, 1234567890))
        before = self.target.stat()
        stale = self.checkout / "tree/home/stale"
        write(stale, "from a previous release")
        result = self.cli("update")
        self.assertEqual(result.returncode, 0, result.stderr)
        after = self.target.stat()
        self.assertEqual((after.st_ino, after.st_mode, after.st_mtime_ns),
                         (before.st_ino, before.st_mode, before.st_mtime_ns))
        self.assertNotIn("Replace?", result.stdout)
        self.assertFalse(stale.exists())
        self.assertFalse((self.home / "stale").exists())

    def test_executable_mode_is_reviewed_and_repaired(self):
        command = Path(".local/bin/example")
        source = self.assets / command
        write(source, "#!/bin/sh\nexit 0\n")
        source.chmod(0o755)
        self.assertEqual(self.cli(umask=0o027).returncode, 0)
        installed = self.home / command
        self.assertEqual(stat.S_IMODE(installed.stat().st_mode), 0o750)
        installed.chmod(0o640)
        result = self.cli(answers="skip\n")
        self.assertIn("old mode 100644", result.stdout)
        self.assertEqual(stat.S_IMODE(installed.stat().st_mode), 0o640)
        self.assertEqual(self.cli(answers="yes\n").returncode, 0)
        self.assertEqual(stat.S_IMODE(installed.stat().st_mode), 0o740)
        self.assertIn("Files installed: 0", self.cli().stdout)

    def test_dirty_checkout_diff_skip_then_yes_preserves_permissions(self):
        for args in (["init", "-q"], ["add", "targets"],
                     ["-c", "user.name=Fixture", "-c", "user.email=test@invalid",
                      "commit", "-qm", "original"]):
            subprocess.run(["git", *args], cwd=self.checkout, env=self.env, check=True)
        self.assertEqual(self.cli().returncode, 0)
        source = self.assets / OPTIONS
        write(source, "HISTSIZE=22222\n")
        write(self.target, "HISTSIZE=11111\n")
        self.target.chmod(0o600)
        result = self.cli("update", "invalid\nskip\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-HISTSIZE=11111\n+HISTSIZE=22222", result.stdout)
        self.assertEqual(result.stdout.count(PROMPT.decode()), 2)
        self.assertEqual(self.target.read_text(), "HISTSIZE=11111\n")
        result = self.cli("update", "yes\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_bytes(), source.read_bytes())
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_batch_cancel_eof_and_skip(self):
        for name in ("b-first", "c-second"):
            write(self.assets / name, "incoming\n")
            write(self.home / name, "personal\n")
        write(self.assets / "a-new/child", "new")
        for answers in ("yes\ncancel\n", "yes\n"):
            with self.subTest(answers=answers):
                result = self.cli(answers=answers)
                self.assertEqual(result.returncode, 130, result.stderr)
                self.assertEqual((self.home / "b-first").read_text(), "personal\n")
                self.assertEqual((self.home / "c-second").read_text(), "personal\n")
                self.assertFalse((self.home / "a-new").exists())
                self.assertFalse((self.home / ".config").exists())
        result = self.cli(answers="yes\nskip\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "b-first").read_text(), "incoming\n")
        self.assertEqual((self.home / "c-second").read_text(), "personal\n")
        self.assertEqual((self.home / "a-new/child").read_text(), "new")

    def test_ctrl_c_during_review(self):
        write(self.home / "review", "personal")
        write(self.assets / "review", "incoming")
        with self.live_update() as process:
            self.prompt(process)
            process.send_signal(signal.SIGINT)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 130)
        self.assertFalse((self.home / ".config").exists())
        self.assertEqual((self.home / "review").read_text(), "personal")

    def test_xdg_zdotdir_and_zsh_after_checkout_move(self):
        for relative in (".zshenv", ".config/zsh/.zshrc"):
            shutil.copy2(REPO / SHARED_HOME / relative, self.assets / relative)
        config = self.root / "custom config"
        self.env["XDG_CONFIG_HOME"] = str(config)
        self.assertEqual(self.cli().returncode, 0)
        self.assertTrue((config / "zsh/options.zsh").is_file())
        self.assertFalse(self.target.exists())

        zsh = self.root / "zsh dotfiles"
        self.env.update(ZDOTDIR=str(zsh), XDG_STATE_HOME=str(self.root / "state"))
        write(self.assets / ".config/example/settings", "test")
        result = self.cli("update")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((config / "example/settings").read_text(), "test")
        self.checkout.rename(self.root / "moved checkout")
        command = (
            '[[ $HISTSIZE == 200000 && -o extended_glob && -o glob_dots && '
            '$HISTFILE == "$XDG_STATE_HOME/zsh/history" && -d ${HISTFILE:h} ]]'
        )
        master, slave = pty.openpty()
        try:
            result = subprocess.run(["zsh", "-ic", command], env=self.env, cwd=self.home,
                                    stdin=slave, stdout=slave, stderr=slave, timeout=5)
            self.assertEqual(result.returncode, 0)
        finally:
            os.close(slave)
            os.close(master)

    def test_data_home_installs_regular_font_files(self):
        relative = Path("fonts/example.ttf")
        source = self.assets / ".local/share" / relative
        write(source, "font fixture")
        data = self.root / "user data"
        self.env["XDG_DATA_HOME"] = str(data)
        self.assertEqual(self.cli().returncode, 0)
        self.assertEqual((data / relative).read_bytes(), source.read_bytes())
        self.assertFalse((data / relative).samefile(source))
        default = self.home / ".local/share" / relative
        self.assertFalse(default.exists())
        self.env["XDG_DATA_HOME"] = "relative"
        self.assertEqual(self.cli().returncode, 0)
        self.assertEqual(default.read_bytes(), source.read_bytes())

    def test_symlink_is_a_conflict_even_for_identical_or_missing_target(self):
        source = self.assets / OPTIONS
        contents = source.read_bytes()
        self.target.parent.mkdir(parents=True)
        for link in (source, self.root / "absent"):
            with self.subTest(link=link):
                self.target.symlink_to(link)
                result = self.cli(answers="skip\n")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(str(link), result.stdout)
                self.assertEqual(self.target.readlink(), link)
                result = self.cli("update", "yes\n", umask=0o077)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.target.is_symlink())
                self.assertEqual(self.target.read_bytes(), contents)
                self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)
                self.target.unlink()
        self.assertEqual(source.read_bytes(), contents)
        self.assertFalse((self.root / "absent").exists())

    def test_directory_conflict_and_parent_link_into_checkout(self):
        self.target.mkdir(parents=True)
        write(self.target / "keep", "mine")
        write(self.assets / "another", "new")
        result = self.cli()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(str(self.target), result.stderr)
        self.assertEqual((self.target / "keep").read_text(), "mine")
        self.assertFalse((self.home / "another").exists())
        (self.home / ".config").rename(self.home / "original")
        (self.home / ".config").symlink_to(self.checkout / "trap")
        result = self.cli("update")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("checkout", result.stderr)
        self.assertFalse((self.checkout / "trap").exists())
        self.assertFalse((self.home / "another").exists())

    def test_binary_review_includes_sizes_and_digests(self):
        old, new = b"\x00installed", b"\x00new"
        (self.home / "data").write_bytes(old)
        (self.assets / "data").write_bytes(new)
        result = self.cli("update", "yes\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Binary files ", result.stdout)
        for content in (old, new):
            self.assertIn(f"{len(content)} bytes", result.stdout)
            self.assertIn(hashlib.sha256(content).hexdigest(), result.stdout)
        self.assertEqual((self.home / "data").read_bytes(), new)

    def test_git_line_ending_normalization_cannot_hide_a_difference(self):
        git_config = self.root / "gitconfig"
        write(git_config, "[core]\n\tautocrlf = input\n")
        self.env["GIT_CONFIG_GLOBAL"] = str(git_config)
        source = self.assets / OPTIONS
        source.write_bytes(b"HISTSIZE=1\r\n")
        write(self.target, "HISTSIZE=1\n")
        result = self.cli("update", "yes\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-HISTSIZE=1", result.stdout)
        self.assertEqual(self.target.read_bytes(), source.read_bytes())

    def test_changed_or_new_destination_is_reviewed_before_any_write(self):
        write(self.assets / "last", "incoming\n")
        write(self.home / "last", "initial\n")
        with self.live_update() as process:
            self.assertIn(b"-initial", self.prompt(process))
            write(self.target, "appeared during review\n")
            process.stdin.write(b"yes\n")
            self.assertIn(b"-appeared during review", self.prompt(process))
            process.communicate(b"cancel\n", timeout=5)
            self.assertEqual(process.returncode, 130)
        self.assertEqual(self.target.read_text(), "appeared during review\n")
        self.assertEqual((self.home / "last").read_text(), "initial\n")

    def test_edit_during_own_prompt_and_later_file_matching_before_its_turn(self):
        for name in ("a", "b"):
            write(self.assets / name, "incoming\n")
            write(self.home / name, "initial\n")
        with self.live_update() as process:
            self.assertIn(b"-initial", self.prompt(process))
            write(self.home / "a", "edited while deciding\n")
            write(self.home / "b", "incoming\n")
            timestamp = (self.home / "b").stat().st_mtime_ns
            process.stdin.write(b"yes\n")
            self.assertIn(b"-edited while deciding", self.prompt(process))
            output, _ = process.communicate(b"skip\n", timeout=5)
            self.assertEqual(process.returncode, 0, output)
        self.assertEqual((self.home / "a").read_text(), "edited while deciding\n")
        self.assertEqual((self.home / "b").stat().st_mtime_ns, timestamp)

    def test_target_inside_staging_is_rejected_before_rebuilding_it(self):
        staged_config = self.checkout / "tree/home/.config"
        previous = staged_config / "zsh/options.zsh"
        write(previous, "preserve this file")
        self.env["XDG_CONFIG_HOME"] = str(staged_config)
        result = self.cli()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("checkout", result.stderr)
        self.assertEqual(previous.read_text(), "preserve this file")

    def test_aliased_destinations_are_reported_before_writes(self):
        write(self.assets / ".config/options.zsh", "overlap")
        self.env["ZDOTDIR"] = str(self.home / ".config")
        result = self.cli()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("same destination", result.stderr)
        self.assertFalse((self.home / ".config").exists())

    def test_apply_failure_reports_completed_paths_and_rerun_recovers(self):
        write(self.assets / "last", "incoming")
        write(self.home / "last", "personal")
        with self.live_update() as process:
            self.prompt(process)
            write(self.checkout / "tree/home/last", "different from the reviewed file")
            output, _ = process.communicate(b"yes\n", timeout=5)
            self.assertEqual(process.returncode, 1, output)
            self.assertIn(b"Completed file writes: 1", output)
            self.assertIn(os.fsencode(self.target), output)
        self.assertEqual(self.target.read_bytes(), (self.assets / OPTIONS).read_bytes())
        self.assertEqual((self.home / "last").read_text(), "personal")
        self.assertFalse(list(self.home.rglob(".lixx-*")))
        self.assertEqual(self.cli("update", "yes\n").returncode, 0)
        self.assertEqual((self.home / "last").read_text(), "incoming")

    def test_concurrent_runs_share_checkout_or_home_lock(self):
        write(self.target, "mine\n")
        other_checkout = self.root / "other checkout"
        shutil.copytree(self.checkout, other_checkout)
        other_home = self.root / "other account"
        other_home.mkdir()
        runs = [(other_checkout, self.env), (self.checkout, {**self.env, "HOME": str(other_home)})]
        for checkout, env in runs:
            with self.subTest(checkout=checkout), self.live_update() as first:
                self.prompt(first)
                with self.live_update(checkout, env) as second:
                    second.stdin.write(b"skip\n")
                    with self.assertRaises(subprocess.TimeoutExpired):
                        second.wait(timeout=0.2)
                    first.communicate(b"cancel\n", timeout=5)
                    self.assertEqual(first.returncode, 130)
                    output, _ = second.communicate(timeout=5)
                    self.assertEqual(second.returncode, 0, output)
