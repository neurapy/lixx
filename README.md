# LIX

This project is the installer and updater for my Ubuntu-based desktop. I will move away from Omarchy step by step and make my own native system.

The repo holds the source configs, native program sources and installation rules. The desktop uses regular files copied to their final locations. Moving or deleting the checkout after installation must leave the desktop fully usable.

Executing the installer on a clean system should give me my complete current OS.

## Install or update

Run `./lixx install` from the checkout as the account that will use the config. To apply subsequent changes, run `./lixx update`. Both commands use the current working files, including uncommitted edits. To install another revision, select it in Git first. The CLI uses system Python 3 and Git.

The first payload is `static_assets/home/.config/zsh/options.zsh`. It installs at `~/.config/zsh/options.zsh` by default. An existing Zsh setup can source it from its `.zshrc`.

```zsh
source "${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/options.zsh"
```

On a difference, review the Git diff and answer `yes`, `skip`, or `cancel`. Review finishes before destination files or directories are created. Existing regular files retain their Unix permission bits, including when you accept replacement. New configs use `0666` filtered by the account's umask. Exit status is `0` on completion (including skips), `130` on cancellation and `1` on an operational error. If applying files fails, Lixx reports the completed writes and the next run compares the live files again.

Run `python3 -m unittest discover -s tests -v` for the CLI acceptance tests. They use temporary checkouts and accounts, Git for diffs, and interactive Zsh for the shell smoke test.

## Proposed repository layout

```text
static_assets/
  home/
    .zshenv
    .config/
      hypr/hyprland.lua
      waybar/style.css
      zsh/options.zsh
      zsh/.zshrc
      systemd/user/lixx-battery-events.service
  rootfs/
    etc/                System-wide config when needed
programs/<name>/        Program source and its build files
targets/ubuntu-26.04/   Ubuntu packages, APT sources and tested versions
install.toml            Build output paths and any required file modes
lixx                    Entry point for install and update
tree/                   Disposable, gitignored staging directory
```

A static file's path gives its default install location. `static_assets/home/` represents the installing user's home directory. For example, `static_assets/home/.config/hypr/hyprland.lua` installs at `~/.config/hypr/hyprland.lua`. Adding a Lua module beside it automatically gives that module the corresponding installed path. `static_assets/rootfs/` represents the filesystem root, so files under `static_assets/rootfs/etc/` go under `/etc/`.

Honor account-specific config locations when expanding those paths. `home/.config/` follows an absolute `XDG_CONFIG_HOME` when set, and `home/.config/zsh/` follows the account's exported `ZDOTDIR` when set. The planned shell setup will supply a `~/.zshenv` for fresh accounts. An existing startup file will get the same review as any other config.

Each run stages the regular files from `static_assets/home/` in a fresh `tree/home/`, preserving paths and dotfiles. Both commands review the staged files individually and install regular copies. Future native builds can add their outputs using the same layout, for example `tree/home/.local/bin/lixx-battery-events`.

Lua and CSS imports resolve to installed assets. The battery service starts `%h/.local/bin/lixx-battery-events`. Give the Python listener an executable entry point using `/usr/bin/python3`. A later native build can take over that path.

## File review on install and update

1. Stage the incoming files before touching their destinations. A missing path queues a new file. A regular file with matching bytes is left in place, preserving its inode, permissions and modification time.
2. For a difference, show the destination and `git diff --no-index -- "$installed" "$staged"` with the installed file on the left and the incoming file on the right. For binaries, show Git's binary-difference summary and both sizes and SHA-256 hashes. [Git diff](https://git-scm.com/docs/git-diff)
3. Prompt for **each** differing file, including files installed by an earlier version of Lixx.

```text
Replace? [yes/skip/cancel]
```

| Answer | Effect |
| --- | --- |
| `yes` | Queue this exact staged file to replace the installed one. |
| `skip` | Keep the installed file and continue reviewing. A later update compares it again. |
| `cancel` | End the review and discard every queued addition and replacement, including earlier Yes choices. |

An existing symlink is a type difference even if its target contains identical bytes. Show the link target. Yes replaces the link itself with a regular file. Skip leaves it visible as an unresolved difference. Resolve each destination's parent and accept only locations outside the checkout and staging tree. This also catches a parent directory linked back into the repo. A directory occupying a file destination is reported as a conflict and its contents are preserved.

After review, recheck the destinations. If a file changed while the user was deciding, review the new difference before applying the plan. Create the necessary parent directories and copy each accepted file to a temporary file beside its destination. Set the file's permissions, then rename it into place. An interrupted run can safely compare the actual files again. Files outside the staged set belong to the user. Any deliberate retirement of a shipped path should be an explicitly reviewed change.

The current installer deploys `home/` files as the target user. The planned system installer will use elevated privileges for reviewed `rootfs/` destinations where needed. APT transactions for dependencies will be a separate step from file review.

## Ubuntu package target

The first target starts from an installed Ubuntu Desktop 26.04 LTS on amd64. Python 3 and Git are the prerequisites for running Lixx from a clone. The desktop package list names the programs and portal backends Lixx needs directly. Each nonblank, noncomment line is one dependency expression for `apt-get satisfy`. APT resolves their libraries. [Desktop package list](targets/ubuntu-26.04/packages.txt) · [APT dependency expressions](https://manpages.ubuntu.com/manpages/resolute/man8/apt-get.8.html)

Use the machine's Ubuntu mirrors, including `universe` for UWSM and Ghostty. Zsh and the GTK portal also come from Ubuntu. The Hyprland PPA supplies the compositor, its portal and Waybar. Its Deb822 source embeds the Launchpad signing key, and its APT preferences allow the packages required for that stack. The two files mirror their destinations under `/etc/apt/`. [PPA on Launchpad](https://launchpad.net/~cppiber/+archive/ubuntu/hyprland) · [PPA source](targets/ubuntu-26.04/etc/apt/sources.list.d/lixx-hyprland.sources) · [Package preferences](targets/ubuntu-26.04/etc/apt/preferences.d/lixx-hyprland.pref)

The compositor requirement starts at the workstation's 0.57.2 baseline. Ubuntu 26.04 ships 0.53.3, and Hyprland introduced Lua config in 0.55. On 2026-11-20 an empty-state APT simulation resolved the list alongside `ubuntu-desktop`, selecting Hyprland 0.57.2 and Waybar 0.16.0 from the PPA and UWSM 0.25.2 from Ubuntu. An archive-only simulation rejected the compositor requirement. [Ubuntu Hyprland package](https://packages.ubuntu.com/resolute/hyprland) · [Hyprland Lua release](https://hypr.land/news/update55/)

Package provisioning is the next installer stage. It should identify the Ubuntu target, configure these APT preferences and source, refresh the indexes, then show and apply the package transaction. After APT succeeds, user-file review runs as the target account. Today `./lixx install` and `./lixx update` implement the user-file stage.

On a machine with the target sources, preferences and package indexes configured, this dry run shows the changes APT would make.

```sh
sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' targets/ubuntu-26.04/packages.txt |
  xargs -r -d '\n' apt-get --simulate --no-remove satisfy
```

## Graphical acceptance test

The first end-to-end test is a fresh Ubuntu VM. Install, move the checkout aside, and start the UWSM-managed Hyprland session from a TTY. Verify that Waybar renders, the terminal opens Zsh, and the battery unit invokes the installed executable. From a different checkout, rerun the same release and check that matching files receive zero writes. Edit two installed configs, choose Yes for the first and Cancel for the second, and verify both edits survive. Repeat with Yes and Skip and verify that only the accepted file changes.
