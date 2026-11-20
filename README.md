# Lixx

This project is the installer and updater for my Ubuntu-based desktop. I will move away from Omarchy step by step and make my own native system.

The repo holds the source configs, native program sources and installation rules. The desktop uses regular files copied to their final locations. Moving or deleting the checkout after installation must leave the desktop fully usable.

Executing the installer on a clean system should give me my complete current OS.

## Preview the current checkout in a VM

From the development checkout, run this in a graphical Linux session.

```sh
./vm/run
```

A QEMU window opens, logs into tty1, runs the real `./lixx install` as the guest user and starts Hyprland through UWSM. The guest login and lock-screen password are both `lixx`. Close the window or run `sudo poweroff` inside the guest when you're finished. If installation fails, tty1 stays open and the installer output is available at `/run/lixx-preview/install.log` inside the guest.

Each invocation creates a fresh disk overlay over a checksum-verified Ubuntu Server image. The guest receives a snapshot of the working tree, including edited files and new, non-ignored files. The launcher discards the overlay when QEMU exits. Run the same command after an edit to see what a new install produces. The disposable guest automatically accepts file replacements and APT's installation prompt. All install writes take place in that guest.

The launcher keeps its files under the checkout's gitignored `vm/.local/` directory. It caches the verified base image in `images/` and creates disposable disks in `runs/`. It uses QEMU from the host's PATH or the unpacked tools in `tools/` on this workstation. Every run resolves and installs the current package profile from the configured archives. [Ubuntu image release](https://cloud-images.ubuntu.com/releases/resolute/release-20261108/)

On another Ubuntu 26.04 development host, the launcher needs Python 3.11 or newer, Git, curl, xorriso and QEMU with GTK and OpenGL support. These packages supply them.

```sh
sudo apt install python3 git curl xorriso qemu-system-x86 qemu-utils qemu-system-gui qemu-system-modules-opengl
```

The target can also be selected explicitly with `./vm/run ubuntu-26.04`. Each preview target pairs a distro supported by `./lixx install` with a cloud-init-enabled amd64 QCOW2 image. Its `vm.toml` sits beside the package profile. Update the release URL and SHA-256 digest together from the distro's signed checksums. [Ubuntu preview profile](targets/ubuntu-26.04/vm.toml)

## Install from a TTY

Start with **Ubuntu Server or Desktop 26.04 LTS on amd64**, an ordinary login account with sudo, and network access to Ubuntu's archives (including `universe`) and the Hyprland PPA. The installer uses Ubuntu's Python 3, Git and APT. For a clean VM, select Ubuntu Server and give it a 3D-capable virtual display. QEMU/KVM with VirtIO graphics and VirGL is the tested configuration.

Log in at a local TTY in the VM window, open the Lixx checkout and run these commands as the desktop user. The first command uses sudo to configure APT, and APT shows its package transaction. The second starts the desktop on that seat. Use the same start command on subsequent logins.

```sh
./lixx install
uwsm start -- hyprland.desktop
```

**Super+Return** opens Ghostty running Zsh, **Super+Space** opens the application launcher, and **Super+W** closes the focused window. **Super+1** through **Super+0** select workspaces. **Super+Shift+E** ends the session and returns to the TTY.

The session loads the workstation's modular Hyprland config, wallpaper, JetBrainsMono Nerd Font and 26-pixel Waybar. UWSM starts the bar, wallpaper, battery listener, idle lock, notification daemon and media controls. Waybar shows five persistent workspaces and the Pomodoro timer. Left-click the timer to start or pause it and right-click to reset it.

Run `./lixx update` to review and apply user files. Rerun `./lixx install` when system files or the package profile change, or to provision another account. Both commands read the current working files, including uncommitted edits. The desktop runs from the installed copies after the checkout is moved or deleted.

## Repository layout

```text
targets/
  all/trees/
    home/
      .zshenv
      .config/hypr/     Hyprland config, modules and wallpaper
      .config/waybar/   Bar layout, CSS and colors
      .config/zsh/
      .config/systemd/user/
      .local/bin/       Session helpers
      .local/share/fonts/lixx/
    root/               Shared system files, relative to /
  ubuntu-26.04/
    tree/
      home/.config/systemd/user/   Ubuntu's UWSM service override
      root/etc/apt/                Ubuntu's APT source and preferences
    packages.txt        Direct package requirements
    vm.toml             Clean base image for the preview
vm/run                  Boot and install a disposable preview from this checkout
lixx                    Entry point for install and update
tree/                   Disposable, gitignored staging directory
```

Put desktop defaults in `targets/all/trees/` and distro-specific additions or replacements in `targets/<id>-<version>/tree/`. Both trees mirror the destination. Paths under `home/` start at the user's home directory and paths under `root/` start at `/`. Lixx selects the target using `ID` and `VERSION_ID` from `/etc/os-release`. On a system without a matching target, `./lixx update` applies the shared home files.

Directories merge. For example, add `targets/ubuntu-26.04/tree/home/.config/waybar/style.css` to replace the shared stylesheet on Ubuntu. The shared `config.jsonc` and `colors.css` still install alongside it. Lixx compares the installed stylesheet once against the Ubuntu copy. A file and directory at the same relative path cause an error before installation.

`home/.config/` and `home/.local/share/` follow absolute `XDG_CONFIG_HOME` and `XDG_DATA_HOME` values. `home/.config/zsh/` follows the account's exported `ZDOTDIR` when set. The supplied `~/.zshenv` locates the installed Zsh configuration on a fresh account. Existing startup files get the same review as any other config.

Each run rebuilds the merged `tree/home/` in the checkout. A full install also builds `tree/root/`. Lixx copies regular files and creates parent directories as needed. A `.gitkeep` directly inside a source `home/` or `root/` only keeps the empty directory in Git. Future builds under `programs/<name>/` can emit files into the same staging layout. For example, a native battery listener could take over the installed Python executable's path at `~/.local/bin/lixx-battery-events`.

Hyprland uses each output's preferred mode. It reads optional `monitors.lua` and `local.lua` from the installed Hypr config directory after the shared modules. Omarchy shortcuts, the SPF file manager workspace and HyprStudy activate when their respective tools are installed. HyprStudy also needs `hyprstudy/settings.toml` in the user's config directory.

The Waybar service starts `~/.local/bin/lixx-waybar`. It includes the installed `waybar/config.jsonc` and selects battery, Bluetooth and dictation modules according to the available devices and commands. The selection lives under `$XDG_RUNTIME_DIR`. Run `systemctl --user restart lixx-waybar.service` to recheck after adding hardware or installing Voxtype. WirePlumber starts its packaged Bluetooth and camera monitors when a device appears.

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

Regular configs retain their permissions on replacement. New configs use `0666` filtered by the account's umask. A source with its owner-execute bit set installs as an executable. A missing owner-execute bit on an otherwise matching installed program gets a mode diff and the same review.

Full install reviews system and home files together before writing any of them. It applies approved APT files with sudo, refreshes indexes and installs packages. If a package creates or changes a destination, Lixx reviews the new difference before applying the remaining system files with sudo and the home files as the login user. New system files use mode `0644`, or `0755` for executables. A failure or cancellation after APT starts can leave earlier APT changes in place. Rerunning compares the live state again. The CLI reports completed file writes on interruption or failure. Its exit status is `0` on success (including skips), `130` on review cancellation or interruption, and `1` on an operational error.

## Ubuntu package target

Each nonblank, noncomment line of the package list is one dependency expression for `apt-get satisfy`. The list includes the session, Mesa, fonts, audio, portal backends and desktop programs needed on a Server installation. APT resolves their dependencies with removals and optional recommendations disabled. [Desktop package list](targets/ubuntu-26.04/packages.txt) · [APT dependency expressions](https://manpages.ubuntu.com/manpages/resolute/man8/apt-get.8.html)

Lixx explicitly requests `hyprland-guiutils`, which provides the dialogs Hyprland checks for at startup. The profile also installs the Hyprland and GTK portals, SwayNC and the PipeWire audio stack required by this session.

Use the machine's Ubuntu mirrors, including `universe` for UWSM and Ghostty. Zsh and the GTK portal also come from Ubuntu. The Hyprland PPA supplies the compositor, its portal and Waybar. Its Deb822 source embeds the Launchpad signing key, and its APT preferences allow the packages required for that stack. The two files mirror their destinations under `/etc/apt/`. [PPA on Launchpad](https://launchpad.net/~cppiber/+archive/ubuntu/hyprland) · [PPA source](targets/ubuntu-26.04/tree/root/etc/apt/sources.list.d/lixx-hyprland.sources) · [Package preferences](targets/ubuntu-26.04/tree/root/etc/apt/preferences.d/lixx-hyprland.pref)

The compositor requirement starts at the workstation's 0.57.2 baseline. Ubuntu 26.04 ships 0.53.3, and Hyprland introduced Lua config in 0.55. On 2026-11-20 an empty-state APT simulation resolved the list alongside `ubuntu-desktop`, selecting Hyprland 0.57.2 and Waybar 0.16.0 from the PPA and UWSM 0.25.2 from Ubuntu. An archive-only simulation rejected the compositor requirement. [Ubuntu Hyprland package](https://packages.ubuntu.com/resolute/hyprland) · [Hyprland Lua release](https://hypr.land/news/update55/)

Add Deb822 `.sources` under `root/etc/apt/sources.list.d/` and `.pref` files under `root/etc/apt/preferences.d/` in either source tree. Lixx discovers these files after combining the trees. When all of a new source's amd64 package indexes are already configured, Lixx reuses the existing entry and applies the selected package preferences. New APT files are root-owned with mode `0644`.

On a machine with the target sources, preferences and package indexes configured, this dry run shows the changes APT would make.

```sh
sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' targets/ubuntu-26.04/packages.txt |
  xargs -r -d '\n' apt-get --simulate --no-remove --no-install-recommends satisfy
```

## Graphical acceptance test

On 2026-11-20 a clean Ubuntu Server 26.04 amd64 VM reached Hyprland 0.57.2 from tty1 after the checkout was moved. The recommended-package banner was gone, `hyprctl configerrors` was empty and Waybar 0.16.0 rendered at 1280 × 26 with a clean service journal. Fuzzel launched Ghostty, Hyprlock locked and unlocked, the Pomodoro timer counted down and the battery alert preview worked. The VM also detected a virtual camera and Bluetooth controller. Physical battery discharge requires a laptop. Xwayland's X11 keycode warnings and Aquamarine's nested-backend and libinput diagnostics remain visible in their respective logs on this VM. [Ubuntu Server image](https://cloud-images.ubuntu.com/releases/resolute/release/)

For a quick desktop check, use `./vm/run`. To also exercise moving the checkout and reviewing local changes, use the following procedure in a VM you manage.

1. Boot a clean Ubuntu Server 26.04 amd64 VM into its local TTY. Copy the working tree to the guest. To include uncommitted changes, run the following from the host checkout, substituting the guest's SSH login.

   ```sh
   tar -cf - lixx targets | ssh user@vm 'mkdir -p ~/lixx && tar -xf - -C ~/lixx'
   ```

2. In the VM console, run `cd ~/lixx && ./lixx install`. Then run `cd ~ && mv lixx lixx-moved` and `uwsm start -- hyprland.desktop`.
3. Check that the wallpaper and bar render without an overlay. Press **Super+Return** and run the following in Ghostty. Expect a monitor, an empty config-error list, the dialog executable, active services and a Zsh version. The Waybar journal should show its installed config and the output dimensions. **Super+Space** should display the launcher.

   ```sh
   hyprctl monitors
   hyprctl configerrors
   command -v hyprland-dialog
   systemctl --user is-active lixx-waybar.service lixx-battery-events.service hypridle.service
   journalctl --user -b -u lixx-waybar.service
   echo "$ZSH_VERSION"
   ```

4. End the session with **Super+Shift+E**. Run `~/lixx-moved/lixx install` again. Matching files should yield `Files installed: 0`. Edit two installed configs and run `./lixx update` from the moved checkout. Answer Yes and Cancel to keep both edits, then repeat with Yes and Skip to apply only the first replacement.

Run `python3 -m unittest discover -s tests -v` from the checkout for the isolated installer tests.
