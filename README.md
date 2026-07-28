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

## Outstanding / not yet done
- Laptop fan not spinning up under load — likely an EC/vendor fan-curve issue not exposed to Linux by default. Needs `lm_sensors` investigation and possibly a vendor-specific tool (`asusctl`/`nbfc-linux`/etc. depending on laptop model).
- KDE Plasma parallel session (considered for GPU validation, not yet installed — SDDM autologin currently left off to keep the session picker available for this).
