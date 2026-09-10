# dotfiles

Personal CachyOS + Hyprland rice setup, built around [ilyamiro](https://github.com/ilyamiro)'s **Serpantinum** shell (formerly distributed as `imperative-dots`/dotfiles for Arch, now a standalone named project — same underlying config, rebranded). This repo documents the full setup so it can be reproduced from a bare CachyOS install.

## System

- **Distro:** CachyOS (Arch-based)
- **Compositor:** Hyprland
- **Kernel:** `linux-cachyos-lts` (switched from mainline `linux-cachyos` — see amdgpu freeze fix below)
- **Shell/UI:** Serpantinum (ilyamiro) — Lua-based Hyprland config as of the in-app update in August 2026
- **Login manager:** SDDM with `sddm-astronaut-theme` (japanese_aesthetic variant)
- **Terminal:** Kitty
- **Laptop:** HP Victus 15-fb2xxx, BIOS F.08
- **CPU/GPU:** AMD Ryzen 5 8645HS, hybrid AMD Radeon 760M (iGPU, default) + NVIDIA GeForce (PRIME offload)

## Setup steps

### 1. Base install
1. Installed CachyOS from the online installer.
2. `sudo pacman -Syu` to update the system.
3. `sudo pacman -S hyprland` for the compositor.
4. Added supporting packages:
   ```
   sudo pacman -S xdg-desktop-portal-hyprland hyprpolkitagent qt5-wayland qt6-wayland
   ```

### 2. Hyprland dotfiles via imperative-dots (original install)
Ran ilyamiro's Arch-native installer (Nix version was considered and rejected since this isn't a NixOS system):
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/imperative-dots/master/install.sh)"
```
- Installed via the `fzf` TUI menu, selecting Hyprland dotfiles, kitty, cava, matugen, etc.
- Skipped the driver-install step (GPU drivers set up manually to preserve the AMD-default / NVIDIA PRIME offload setup).
- Original config lived at `~/.config/hypr/`, with keybinds and settings driven by `default_settings.json` (plain `hyprland.conf`, pre-Lua).

### 2a. Migration to Serpantinum / Lua config (August 2026)
The shell has a built-in **update button in the topbar** — clicking it pulled the current Serpantinum release and **completely restructured the config**, replacing the old JSON-driven files with a native Lua API:

```
~/.config/hypr/
├── hyprland.conf       # minimal, mostly delegates to hyprland.lua now
├── hyprland.lua        # actual active config entrypoint
└── config/
    ├── autostart.lua
    ├── env.lua
    ├── keybinds.lua    # was keybindings.conf / default_settings.json
    ├── monitors.lua
    ├── settings.lua    # was settings.conf
    └── variables.lua
```

**⚠️ The update wiped all custom tweaks** (Zen Browser keybind, Num Lock, kitty font size) back to Serpantinum's defaults — it does **not** preserve local edits to the generated config files. Since then, tweaks are re-applied against the new Lua files (below) each time. **Always back up first before hitting that update button:**
```
cp -r ~/.config/hypr ~/.config/hypr.backup-$(date +%Y%m%d)
```

New Lua config uses an `hl.*` API, e.g.:
```lua
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.config({ input = { kb_layout = "us", ... } })
```
Panel commands also changed: old `qs_manager.sh toggle <panel>` → new `serpantinum msg toggle <panel>`. Some panels were renamed/merged in the rewrite (e.g. the old separate "battery" panel is now folded into a broader "system" panel via `SUPER+B`); a few old bindings (movies, dedicated settings, focus timer, next-monitor-focus) aren't present in the new default keybinds — possibly moved inside another panel, not yet confirmed.

### 3. Login manager — SDDM
```
sudo pacman -S sddm
sudo systemctl enable sddm
```
Installed the astronaut theme pack and selected the **japanese_aesthetic** variant:
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
```
Theme variant is set via `ConfigFile=Themes/japanese_aesthetic.conf` in the theme's `metadata.desktop`, with `/etc/sddm.conf` pointing `Current=sddm-astronaut-theme`.

### 4. Keybind tweaks
**Post-Lua-migration versions** (current), edited in `~/.config/hypr/config/keybinds.lua`:
```
sed -i 's|hl.dsp.exec_cmd("firefox")|hl.dsp.exec_cmd("zen-browser")|' ~/.config/hypr/config/keybinds.lua
sed -i 's/mainMod .. " + RETURN"/mainMod .. " + T"/' ~/.config/hypr/config/keybinds.lua
hyprctl reload
```
- `SUPER+F` → Zen Browser instead of Firefox
- Terminal moved from `SUPER+RETURN` to `SUPER+T` (RETURN stopped working after the Lua migration, possibly a submap remnant from the old config — not fully root-caused, just rebound instead)

Num Lock on by default, added to the `input` table in `~/.config/hypr/config/settings.lua`:
```
sed -i '/kb_layout = "us",/a\    numlock_by_default = true,' ~/.config/hypr/config/settings.lua
```

**Pre-migration versions** (for reference, no longer applicable post-update):
```json
{"type":"bind","mods":"$mainMod","key":"F","dispatcher":"exec","command":"zen-browser"}
```

### 5. Discord
**Originally Vesktop + ClearVision theme** (Vesktop uses Vencord internally, not BetterDiscord) — added via Settings → Vencord → Themes → Online Themes → `https://raw.githubusercontent.com/ClearVision/ClearVision-v7/master/ClearVision-v7.theme.css`.

**Switched to plain Discord** (pacman-managed, `/usr/bin/discord`):
```
sudo pacman -Rns vesktop
sudo pacman -S discord
```
Attempted to stop the "checking for updates" screen on every launch by adding `"SKIP_HOST_UPDATE": true` to `~/.config/discord/settings.json` — **did not fully suppress it** (still shows the update check/download on launch as of last check). Left as-is for now; not worth chasing further at this time.

### 5a. Laptop freezing — amdgpu `flip_done timed out`
Diagnosed via `journalctl -b -1 -k` showing a kernel crash trace: `amdgpu 0000:06:00.0: [drm] *ERROR* flip_done timed out` → `acrtc->pflip_status != AMDGPU_FLIP_NONE` warning → crash in `dm_arm_vblank_event`. This is a known, actively-discussed amdgpu display-commit bug (CachyOS forum thread: "Amdgpu flip_done timed out - Display reset"), suspected linked to VRR/FreeSync, affecting various AMD GPU generations across recent kernels.

Mitigations applied (VRR was already off; kernel switch is the main fix being tested):
```
sudo pacman -S linux-cachyos-lts linux-cachyos-lts-headers
sudo pacman -S linux-firmware
sudo grub-mkconfig -o /boot/grub/grub.cfg
```
Rebooted and manually selected **CachyOS Linux LTS** from the GRUB menu. Confirm active kernel:
```
uname -r
```
**Status: monitoring** — switched kernel, watching for recurrence over the following days before considering it resolved.

### 5b. Num Lock on by default + Bluetooth off by default
**Num Lock** — two layers, SDDM login screen and Hyprland session:
```
# /etc/sddm.conf — added under [General]
Numlock=on
```
```
# ~/.config/hypr/config/settings.lua — input table
numlock_by_default = true,
```

**Bluetooth off at boot** (service stays available, just doesn't auto-power the radio):
```
# /etc/bluetooth/main.conf — under [Policy]
AutoEnable=false
```
```
sudo systemctl restart bluetooth
```

### 6. Spotify + Spicetify, version-locked together
Goal: Spotify should never auto-update on its own — it only updates when Spicetify gets a new release, to avoid Spicetify patches breaking against a newer Spotify build.

**Install:**
```
yay -S spotify
curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
sudo chown -R $USER:$USER /opt/spotify   # AUR package installs root-owned; Spicetify needs write access
spicetify backup apply
```

**Freeze Spotify from normal system updates** (`/etc/pacman.conf`):
```
IgnorePkg = spotify
```

**Auto-sync hook** — fires whenever `spicetify-cli` is upgraded via AUR, force-updates Spotify to match, then re-patches it:

`/usr/local/bin/spotify-sync.sh`:
```bash
#!/bin/bash
pacman -S --noconfirm spotify
chown -R $USER:$USER /opt/spotify
spicetify backup apply
```

`/etc/pacman.d/hooks/spicetify-sync.hook`:
```ini
[Trigger]
Operation = Upgrade
Type = Package
Target = spicetify-cli

[Action]
Description = Updating Spotify and re-applying Spicetify after Spicetify upgrade...
When = PostTransaction
Exec = /usr/local/bin/spotify-sync.sh
```

**Known caveat:** if the AUR `spotify` package version lags behind what Spicetify expects (or vice versa), `spicetify backup apply` may briefly fail after the hook runs — rerun it manually once versions line up. Nothing breaks permanently; worst case Spotify runs unpatched until then.

### 7. Fixing broken CachyOS mirrors
Ran into repeated `404` errors on package installs (`cmake`, `libreoffice-fresh`, later `gcc`, DaVinci Resolve deps) traced to bad/stale/outage-affected entries across the `znver4` and `v4` tier mirrorlists. At times every third-party community mirror (and briefly even `cdn77.cachyos.org` itself) started 404ing on the same `.db` index files simultaneously — a mirror-pool-wide sync/outage issue upstream, not a local config problem. Confirmed via the official status tooling that CachyOS's own build pipeline for a given tier can genuinely stall for days at a time (e.g. `znver4` had no new builds for about a week in late July 2026).

**Reliable fix (confirmed working) — clear the local package cache and regenerate mirrors with CachyOS's own official tool, rather than manual edits or the AUR `rate-mirrors`:**
```
sudo pacman -Scc
sudo cachyos-rate-mirrors
sudo pacman -Syyu
```
`pacman -Scc` clears out stale/partial cached files that can cause confusing follow-on errors even after the mirror itself is fixed. `cachyos-rate-mirrors` is CachyOS's maintained mirror-ranking tool (distinct from the generic AUR `rate-mirrors` package) and should be the first thing reached for on any repo/mirror weirdness going forward.

**One-off emergency fallback** (only if `cachyos-rate-mirrors` itself can't be reached, e.g. mid-outage): point directly at CachyOS's own CDN, bypassing the mirror pool entirely:
```
echo "Server = https://cdn77.cachyos.org/repo/x86_64_v4/\$repo" | sudo tee /etc/pacman.d/cachyos-v4-mirrorlist
```
This leaves a single mirror with no fallback — only use temporarily, and re-run `cachyos-rate-mirrors` once things stabilize to restore a proper multi-mirror list.

**Quick way to check if a specific tier's database is actually being served** (before assuming it's your config):
```
curl -sI https://cdn77.cachyos.org/repo/x86_64_v4/cachyos-extra-v4/cachyos-extra-v4.db
```
`HTTP/2 200` with a recent `last-modified` = healthy. `404` = genuine upstream outage for that tier, not a local mirror problem — check https://status.cachyos.org/ and CachyOS's Discord `#announcements`/`#updates-repo` for confirmation.

### 8. VSCodium for C++ coursework
```
yay -S vscodium-bin
sudo pacman -S gcc gdb cmake make clang
```
Extensions installed inside VSCodium (via Open VSX, not the MS marketplace):
- **clangd** (llvm-vs-code-extensions) — completion, diagnostics, go-to-definition
- **CodeLLDB** (vadimcn) — debugging/breakpoints
- **CMake Tools** — for future multi-file/CMake-based projects

Verified working with a throwaway `test.cpp` compiled via `g++ test.cpp -o test && ./test` from VSCodium's integrated terminal.

### 9. LibreOffice
```
sudo pacman -S libreoffice-fresh
```
Used in place of Microsoft Word/Excel for coursework — reads/writes `.docx`/`.xlsx` natively.

### 10. DaVinci Resolve
Available directly in CachyOS's own repos (`cachyos/davinci-resolve`), no AUR/manual download needed:
```
sudo pacman -S davinci-resolve
```
Pulls in a Java runtime as a dependency — accept the default provider (`jdk-openjdk`) when prompted. Installation is large (~3.2 GB download, ~7.7 GB installed) so make sure mirrors are healthy first (see mirror troubleshooting above) before starting.

### 11. User management
Change own password:
```
passwd
```
Add a new user (with sudo access via `wheel` group, fish as default shell):
```
sudo useradd -m -G wheel -s /usr/bin/fish username
sudo passwd username
```
Confirm `wheel` is enabled for sudo (uncomment in `sudo visudo` if needed: `%wheel ALL=(ALL:ALL) ALL`). New users automatically show up on the SDDM login screen — no extra config needed.

Delete a user (keeps home dir by default; `-r` removes it too):
```
sudo userdel username        # keeps /home/username
sudo userdel -r username     # full removal
```

### 12. SDDM virtual keyboard removal
The astronaut theme setup enabled `qtvirtualkeyboard` as an input method, which caused an on-screen keyboard to pop up automatically on the login screen — not needed on a laptop with a physical keyboard. Traced to `/etc/sddm.conf.d/virtualkbd.conf`; removed entirely:
```
sudo rm /etc/sddm.conf.d/virtualkbd.conf
```

### 13. fastfetch — expanded system info
Serpantinum ships a minimal custom fastfetch config (`~/.config/fastfetch/config.jsonc`) showing just OS/CPU/RAM/shell. Expanded it using fastfetch's built-in interactive generator rather than hand-editing JSON:
```
fastfetch --gen-config
```
This launches a TUI module picker (`↑/↓` move, `Space` toggle, `s`/`Enter` save) — selected kernel, uptime, packages, host, display, WM, theme/cursor/icons/fonts, CPU cache, both GPUs, disk, battery, local IP, and colors, in addition to the original set. Config lives at `~/.config/fastfetch/config.jsonc`; safe to re-run `--gen-config` any time to adjust the module list.

## Hyprland keybinds (current, post-Lua-migration)
Pulled from `~/.config/hypr/config/keybinds.lua` as of the Serpantinum update. **Note:** this file gets reset to defaults every time the topbar update button is used — back up first, then re-diff/reapply custom binds after updating.

**Window management**
| Shortcut | Action |
|---|---|
| `ALT + F4` | Close focused window |
| `SUPER + SHIFT + F` | Toggle floating mode |
| `SUPER + CTRL + ←/→/↑/↓` | Move focused window |
| `SUPER + ←/→/↑/↓` | Move focus |
| `SUPER + SHIFT + ←/→/↑/↓` | Resize focused window |
| `SUPER + mouse-drag` / `SUPER + mouse-right-drag` | Drag / resize window with mouse |
| 3-finger swipe (touchpad) | Switch workspace |

**App launching**
| Shortcut | Action |
|---|---|
| `SUPER + T` | Open Kitty (rebound from `SUPER+RETURN`, which stopped working after the Lua migration) |
| `SUPER + F` | Open Zen Browser (custom rebind, default is Firefox) |
| `SUPER + E` | Open Nautilus |
| `SUPER + D` | Toggle app launcher |

**Serpantinum panel toggles** (`serpantinum msg toggle <panel>`)
| Shortcut | Panel |
|---|---|
| `SUPER + C` | Clipboard manager |
| `SUPER + Q` | Music |
| `SUPER + B` | System (was separate "battery" panel pre-migration — merged) |
| `SUPER + W` | Wallpaper picker |
| `SUPER + S` | Calendar |
| `SUPER + N` | Network |
| `SUPER + V` | Volume |
| `SUPER + H` | Guide/help overlay |

**Not present in the new default keybinds** (existed pre-migration; possibly moved inside another panel, not yet confirmed): movies panel, dedicated settings panel (separate from system), focus timer, next-monitor-focus (`SUPER+TAB`).

**Media / power / screenshots** (new since migration)
| Shortcut | Action |
|---|---|
| `SUPER + SPACE` / `XF86AudioPlay` / `XF86AudioPause` | Play/pause media |
| `XF86AudioMute` / `XF86AudioMicMute` | Mute speaker / mic |
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` | Volume up/down |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | Brightness up/down |
| `Print` | Screenshot (region) |
| `SHIFT + Print` | Screenshot (region, edit) |
| `SUPER + Print` | Screenshot (full) |
| `SUPER + SHIFT + Print` | Screenshot (full, edit) |
| `SUPER + L` / `XF86PowerOff` | Lock screen |

**Workspaces**
| Shortcut | Action |
|---|---|
| `SUPER + 1–9, 0` | Switch to workspace 1–10 |
| `SUPER + SHIFT + 1–9, 0` | Move focused window to workspace 1–10 |

**System**
| Shortcut | Action |
|---|---|
| `SUPER + R` | Reload (`serpantinum reload`) |

## Repo structure
```
My-CachyOS-dotfiles/     # renamed from "dotfiles", made public (Aug 2026)
├── hypr/                # Hyprland config — now Lua (hyprland.lua, config/*.lua)
├── kitty/               # Kitty terminal config
├── scripts/
│   ├── spotify-sync.sh
│   └── spicetify-sync.hook
├── sddm/                # SDDM theme config notes
└── README.md
```
Repo visibility switched from private → public, and renamed from `dotfiles` to `My-CachyOS-dotfiles` (GitHub converts spaces to hyphens in the slug). Local remote updated accordingly:
```
git remote set-url origin https://github.com/exoticidiot/My-CachyOS-dotfiles.git
```

## Other repos
- **[Book-Library-Management-System](https://github.com/exoticidiot/Book-Library-Management-System)** — console C++ library management app (structs/arrays, ISBN-13 validation). Replaced the leftover assignment-brief README with real usage docs; added About description + topics.
- **[Minesweeper](https://github.com/exoticidiot/Minesweeper)** — console C++ Minesweeper (2D arrays, no classes/pointers). Fixed a README bug where the run instructions referenced the wrong filename (`minesweeper.cpp` vs actual `Minesweeper Game.cpp`); added About description + topics.

## Resolved / decided against
- **Laptop fan concern** — turned out to be a non-issue; fan runs correctly under load.
- **KDE Plasma parallel session** — considered for GPU/PRIME validation, decided not worth the extra maintenance since Hyprland + PRIME already runs fine day-to-day. Lighter one-off validation if ever needed:
  ```
  glxinfo | grep "OpenGL renderer"
  prime-run glxinfo | grep "OpenGL renderer"
  ```

## Outstanding / not yet done
- **Discord "checking for updates" screen on launch** — `SKIP_HOST_UPDATE: true` in `~/.config/discord/settings.json` did not suppress it. Not investigated further yet.
- **amdgpu freeze fix (LTS kernel)** — confirmed running `6.18.48-1-cachyos-lts` via `fastfetch`/`uname -r`; no freezes recurred since the switch. Still monitoring before fully marking resolved.
- **Serpantinum panel migration** — confirm whether movies/dedicated-settings/focus-timer panels moved inside the new "system" panel or were dropped entirely.
- **Serpantinum topbar update button** — wipes all custom config edits on every use (confirmed by experience). Always back up `~/.config/hypr` first: `cp -r ~/.config/hypr ~/.config/hypr.backup-$(date +%Y%m%d)`.
