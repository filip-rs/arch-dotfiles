# Arch dotfiles

My (most important) Arch Linux dotfiles — configs and settings I use daily on my
Hyprland machines. Some of it is fully custom, some is sourced from various
places (see [Credits](#credits)).

## Layout

```
arch-dotfiles/
├── dotfiles/              # GNU stow tree (dot- prefix → hidden file)
│   ├── dot-config/        # → ~/.config/
│   │   ├── hypr/          # Hyprland 0.55+ config, written in Lua
│   │   ├── hyprback/      # old pre-Lua hypr configs, kept for reference
│   │   ├── nvim/          # Neovim (lua/filip/), CI-checked
│   │   ├── waybar/        # bar config + custom status scripts
│   │   ├── wofi/  swaync/  wlogout/  nwg-dock-hyprland/  nwg-look/
│   │   ├── alacritty/  ghostty/  zathura/  pacseek/
│   │   ├── fastfetch/  neofetch/  matugen/  wireplumber/
│   ├── dot-tmux.conf      # → ~/.tmux.conf
│   ├── dot-zshrc          # → ~/.zshrc
├── desktopentries/        # .desktop files (see desktopentries.md)
├── pacman-list.txt        # explicit pacman packages for restore
└── .github/workflows/     # nvim-check.yml — CI validates the Neovim config
```

Managed with **GNU stow**. The `dot-` prefix maps to a leading dot when stowing
with `--dotfiles`: `dot-zshrc` → `~/.zshrc`, `dot-config/` → `~/.config/`.

## Install

**ALWAYS TAKE A BACKUP FIRST** — stowing will happily overwrite existing files.

1. Clone the repository:

   ```bash
   git clone https://github.com/filip-rs/arch-dotfiles.git
   # or: git clone git@github.com:filip-rs/arch-dotfiles.git
   ```

2. Stow everything from inside `dotfiles/`:

   ```bash
   cd arch-dotfiles/dotfiles
   stow . --dotfiles -t $HOME
   ```

   That stows the whole tree. For a single app the simplest honest move is to
   copy just that dir, e.g. `cp -r dot-config/waybar ~/.config/`.

3. Desktop entries (optional — installs to `~/.local/share/applications`,
   see `desktopentries.md`):

   ```bash
   cd arch-dotfiles/desktopentries
   stow . -t ~/.local/share/applications
   ```

4. Set up your Hyprland host config — `host.lua` is gitignored per machine,
   `host.lua.example` is the tracked template:

   ```bash
   cp ~/.config/hypr/host.lua.example ~/.config/hypr/host.lua
   # then edit; find outputs/modes with: hyprctl monitors all
   ```

## Packages

`pacman-list.txt` (1.2k+ explicit packages) can be restored with:

```bash
pacman -S --needed - < pacman-list.txt
```

## Hyprland notes

- Config is written in **Hyprland's Lua format (0.55+)**, entry point
  `~/.config/hypr/hyprland.lua`, split into modules under `lua/`
  (`env`, `monitors`, `input`, `binds`, `looknfeel`, `animations`, `plugins`,
  `rules`, `theme`, `autostart`).
- Per-machine settings (monitors, host env) live in `host.lua` — not tracked.
  `scripts/monitor_apply.sh` can rewrite the monitor section for you.
- `scripts/quickshell/` holds helper scripts for the Quickshell widgets
  (network/audio/bluetooth panels, music, mullvad relays, weather).
- `hyprback/` is the old conf-based setup kept around for reference.

## CI

`.github/workflows/nvim-check.yml` runs on every push/PR touching the Neovim
config: installs plugins headlessly, builds the treesitter parsers, and runs a
smoke test (`scripts/ci-check.lua`) that fails the build if the config errors.

## Credits

- Neovim config is my own structure today (`lua/filip/`), but it grew out of
  Joséan Martinez's setup (the old `lua/josean/` paths in git history).
- Waybar custom modules, Wofi/Waybar theming and various scripts are picked up
  from around the r/unixporn / Hyprland community and adapted.
- Everything else: written by me unless the file says otherwise.
