# LIX

This project is the installer and updater for my Ubuntu-based desktop. I will move away from Omarchy step by step and make my own native system.

The repo holds the source configs, native program sources and installation rules. The desktop uses regular files copied to their final locations. Moving or deleting the checkout after installation must leave the desktop fully usable.

Executing the installer on a clean system should give me my complete current OS.

## Proposed repository layout

```text
static_assets/
  home/
    .zshenv
    .config/
      hypr/hyprland.lua
      waybar/style.css
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

Honor account-specific config locations when expanding those paths. `home/.config/` follows `XDG_CONFIG_HOME` when set, and `home/.config/zsh/` follows the account's `ZDOTDIR` when set. On a fresh account the supplied `~/.zshenv` selects `${XDG_CONFIG_HOME:-$HOME/.config}/zsh`. An existing startup file gets the same review as any other config.

The proposed `./lixx install` builds from the checkout. `./lixx update` stages the selected release. Each run copies the contents of `static_assets/` into a fresh `tree/`, preserving the paths and dotfiles. Builds add their outputs using the same layout. For example, `programs/battery-events/` produces `tree/home/.local/bin/lixx-battery-events`. Both commands review the staged files individually and install regular copies.

Lua and CSS imports resolve to installed assets. The battery service starts `%h/.local/bin/lixx-battery-events`. Give the Python listener an executable entry point using `/usr/bin/python3`. A later native build can take over that path.

## File review on install and update

1. Build and stage the incoming files before touching their destinations. Check each destination's type, contents and any required mode against the staged file. A missing path queues a new file. A matching regular file is left in place, preserving its modification time.
2. For a difference, show the destination and `git diff --no-index -- "$installed" "$staged"` with the installed file on the left and the incoming file on the right. For binaries, show Git's binary-difference summary and both sizes and SHA-256 hashes. Show required permission changes explicitly, including when the bytes match. [Git diff](https://git-scm.com/docs/git-diff)
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

After review, recheck the destinations. If a file changed while the user was deciding, review the new difference before applying the plan. Create the necessary parent directories and copy each accepted file to a temporary file beside its destination. Set its required mode, then rename it into place. An interrupted run can safely compare the actual files again. Files outside the staged set belong to the user. Any deliberate retirement of a shipped path should be an explicitly reviewed change.

Install `home/` files as the target user. Use elevated privileges for reviewed `rootfs/` files where the destination requires them. Any APT transaction for system packages or build dependencies is a separate step from this file review.

## Ubuntu target and first acceptance test

Start with Ubuntu 26.04 LTS on amd64, matching the workstation. APT supplies dependencies from Ubuntu and the allowlisted `ppa:cppiber/hyprland` packages. Record the PPA's `Signed-By` key and tested versions in the Ubuntu target. The Ubuntu archive ships Hyprland 0.53.3, while the workstation's Lua config uses a feature introduced in 0.55. A dependency simulation with those sources resolved Ubuntu Desktop, Hyprland 0.57.2, Waybar, Ghostty, Zsh and UWSM together. [Ubuntu package](https://packages.ubuntu.com/resolute/hyprland) · [Hyprland Lua release](https://hypr.land/news/update55/)

The first end-to-end test is a fresh Ubuntu VM. Install, move the checkout aside, and start the UWSM-managed Hyprland session from a TTY. Verify that Waybar renders, the terminal opens Zsh, and the battery unit invokes the installed executable. From a different checkout, rerun the same release and check that matching files receive zero writes. Edit two installed configs, choose Yes for the first and Cancel for the second, and verify both edits survive. Repeat with Yes and Skip and verify that only the accepted file changes.
