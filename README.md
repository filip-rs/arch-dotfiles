# Arch dotfiles

My (most important) Arch Linux dotfiles — configs and settings I use daily on my
Hyprland machines. Some of it is fully custom, some is sourced from various
places (see [Credits](#credits)).

## Layout

```
arch-dotfiles/
├── dotfiles/
│   ├── dot-config/        # ~/.config/
│   │   ├── hypr/          # Hyprland 0.55+ config
│   │   ├── nvim/          # Neovim (lua/filip/)
│   │   ├── waybar/        # bar config + custom status scripts
│   │   ├── wofi/  swaync/  wlogout/  nwg-dock-hyprland/  nwg-look/
│   │   ├── alacritty/  ghostty/  zathura/  pacseek/
│   │   └── fastfetch/  neofetch/  matugen/  wireplumber/
│   │
│   ├── dot-tmux.conf      # ~/.tmux.conf
│   └── dot-zshrc          # ~/.zshrc
│
├── desktopentries/        # .desktop files (see desktopentries.md)
├── pacman-list.txt        # all my pkgs
└── .github/workflows/     # CI for the Neovim config
```

Managed with **GNU stow**. The `dot-` prefix maps to a dot when stowing
with `--dotfiles`: `dot-zshrc` -> `~/.zshrc`, `dot-config/` -> `~/.config/`.

## Install

**ALWAYS TAKE A BACKUP FIRST**

1. Clone the repository:

   ```bash
   git clone https://github.com/filip-rs/arch-dotfiles.git
   ```

2. Stow everything from inside `dotfiles/`:

   ```bash
   cd arch-dotfiles/dotfiles
   stow . --dotfiles -t $HOME
   ```

   That installs all my dotfiles to your system, if you rather just want a single part
   it's easier to just symlink or copy a folder individually.

3. Desktop entries installs to `~/.local/share/applications`,
   see `desktopentries.md`:

   ```bash
   cd arch-dotfiles/desktopentries
   stow . -t ~/.local/share/applications
   ```

4. Set up your Hyprland host config, `host.lua` is gitignored per machine,
   but `host.lua.example` is the template you can use from this repo:

   ```bash
   cp ~/.config/hypr/host.lua.example ~/.config/hypr/host.lua
   # then edit; find outputs/modes with: hyprctl monitors all
   ```

## Packages

You probably don't want to install this, it's mostly for backup of my own machine but if you
are me in the future this could be quite useful.

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

- Neovim config is practically entirely rewritten, but it grew out of
  Joséan Martinez's setup from back in 2024.
- Waybar custom modules, Wofi/Waybar theming and various scripts are picked up
  from various places and adapted.
- The entire Quickshell stack is reimplemented for my setup from a shell I found online somewhere
  will add credits to it someday if I find it again but I don't. If you recognise it
  please make an issue about who made the original modules, they are quite recognisable.
