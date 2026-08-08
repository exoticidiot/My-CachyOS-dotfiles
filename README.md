# dotfiles

Personal CachyOS + Hyprland rice setup, built around [ilyamiro](https://github.com/ilyamiro)'s `imperative-dots` (Caelestia-style shell). This repo documents the full setup so it can be reproduced from a bare CachyOS install.

## System

- **Distro:** CachyOS (Arch-based)
- **Compositor:** Hyprland
- **Shell/UI:** Caelestia-style shell via `imperative-dots`
- **Login manager:** SDDM with `sddm-astronaut-theme` (japanese_aesthetic variant)
- **Terminal:** Kitty
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

### 2. Hyprland dotfiles via imperative-dots
Ran ilyamiro's Arch-native installer (Nix version was considered and rejected since this isn't a NixOS system):
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ilyamiro/imperative-dots/master/install.sh)"
```
- Installed via the `fzf` TUI menu, selecting Hyprland dotfiles, kitty, cava, matugen, etc.
- Skipped the driver-install step (GPU drivers set up manually to preserve the AMD-default / NVIDIA PRIME offload setup).
- Config lives at `~/.config/hypr/`, with keybinds and settings driven by `default_settings.json` rather than plain `hyprland.conf`/`hyprland.lua`.

**Note:** Hyprland 0.55+ defaults to a Lua config (`hyprland.lua`) unless a distro/dotfile setup overrides it — this setup uses the JSON-driven config from imperative-dots instead, generated into the actual Hyprland config at runtime.

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
Changed `SUPER+F` to launch Zen Browser instead of Firefox by editing `~/.config/hypr/default_settings.json`:
```json
{"type":"bind","mods":"$mainMod","key":"F","dispatcher":"exec","command":"zen-browser"}
```

### 5. Discord — Vesktop + ClearVision theme
Vesktop uses Vencord internally (not BetterDiscord), so ClearVision was added via Vencord's built-in online theme support:
- Settings → Vencord → Themes → Online Themes
- Added: `https://raw.githubusercontent.com/ClearVision/ClearVision-v7/master/ClearVision-v7.theme.css`

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

## Hyprland keybinds
Full current keybind reference, pulled from `~/.config/hypr/default_settings.json`:

**Window management**
| Shortcut | Action |
|---|---|
| `ALT + F4` | Close focused window |
| `SUPER + SHIFT + F` | Toggle floating mode |
| `SUPER + CTRL + ←/→/↑/↓` | Move focused window |
| `SUPER + ←/→/↑/↓` | Move focus |
| `SUPER + TAB` | Focus next monitor |

**App launching**
| Shortcut | Action |
|---|---|
| `SUPER + RETURN` | Open Kitty |
| `SUPER + F` | Open Zen Browser (custom rebind, was Firefox) |
| `SUPER + E` | Open Nautilus |
| `SUPER + D` | Toggle app launcher |

**Quickshell panel toggles**
| Shortcut | Panel |
|---|---|
| `SUPER + C` | Clipboard manager |
| `SUPER + P` | Movies |
| `SUPER + SHIFT + S` | Settings |
| `SUPER + Q` | Music |
| `SUPER + B` | Battery |
| `SUPER + W` | Wallpaper picker |
| `SUPER + S` | Calendar |
| `SUPER + N` | Network |
| `SUPER + SHIFT + T` | Focus timer |
| `SUPER + V` | Volume |
| `SUPER + H` | Guide/help overlay |

**Workspaces**
| Shortcut | Action |
|---|---|
| `SUPER + 1–9, 0` | Switch to workspace 1–10 |
| `SUPER + SHIFT + 1–9, 0` | Move focused window to workspace 1–10 |

**System**
| Shortcut | Action |
|---|---|
| `SUPER + R` | Reload Hyprland config |

## Repo structure
```
dotfiles/
├── hypr/               # Hyprland config (default_settings.json, session files)
├── kitty/              # Kitty terminal config
├── scripts/
│   ├── spotify-sync.sh
│   └── spicetify-sync.hook
├── sddm/               # SDDM theme config notes
└── README.md
```

## Resolved / decided against
- **Laptop fan concern** — turned out to be a non-issue; fan runs correctly under load.
- **KDE Plasma parallel session** — considered for GPU/PRIME validation, decided not worth the extra maintenance since Hyprland + PRIME already runs fine day-to-day. Lighter one-off validation if ever needed:
  ```
  glxinfo | grep "OpenGL renderer"
  prime-run glxinfo | grep "OpenGL renderer"
  ```

## Outstanding / not yet done
- None currently tracked.
