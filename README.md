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
Ran into repeated `404` errors on package installs (`cmake`, `libreoffice-fresh`) traced to bad/stale entries in the `znver4`-tier mirrorlist (`/etc/pacman.d/cachyos-v4-mirrorlist`). Eventually every third-party community mirror started 404ing on the same `.db` index files simultaneously — a mirror-pool-wide sync issue, not a local config problem.

**Fix — point directly at CachyOS's own CDN, bypassing the community mirror pool:**
```
echo "Server = https://cdn77.cachyos.org/repo/x86_64_v4/\$repo" | sudo tee /etc/pacman.d/cachyos-v4-mirrorlist
sudo pacman -Syyu
```
**Note:** this leaves only a single mirror with no fallback. Worth revisiting later — re-run the official CachyOS repo installer or `rate-mirrors` once the community mirror pool recovers, to rebuild a fuller list with this CDN entry kept as a backup rather than the only source.

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
