# Arch dotfiles

My (most important) Arch Linux dotfiles — configs and settings I use daily on my
Hyprland machines: `archflipper` (laptop) and `archbased` (desktop) run the same
repo at the same time. Some of it is fully custom, some is sourced from various
places (see [Credits](#credits)).

## Layout

```
arch-dotfiles/
├── dotfiles/
│   ├── dot-config/        # ~/.config/
│   │   ├── hypr/          # Hyprland 0.55+ config (Lua), hosts/<hostname>.lua per machine
│   │   ├── quickshell/    # Quickshell panels, lockscreen and their helper scripts
│   │   ├── scripts/
│   │   │   ├── desktop/   # theme/wallpaper pipeline, qs_manager, brightness, screenshots, themes/
│   │   │   └── lib/       # compositor.sh (shared Hyprland calls)
│   │   ├── nvim/          # Neovim (lua/filip/)
│   │   ├── waybar/        # bar config + custom status scripts
│   │   ├── wofi/  swaync/  swayosd/  wlogout/  nwg-look/  matugen/
│   │   ├── alacritty/  ghostty/  zathura/  pacseek/
│   │   └── fastfetch/  neofetch/  wireplumber/
│   │
│   ├── dot-local/         # ~/.local/ (wireplumber scripts)
│   ├── dot-tmux.conf      # ~/.tmux.conf
│   └── dot-zshrc          # ~/.zshrc
│
├── desktopentries/        # .desktop files (see desktopentries.md)
├── pkglist.txt            # official-repo packages (pacman)
├── aurlist.txt            # AUR packages (paru)
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

2. Stow everything from inside `dotfiles/`. Re-run this after pulling changes
   that add new folders (it only adds links):

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

4. Per-machine Hyprland settings:
   - `hypr/hosts/<hostname>.lua` is tracked and picked by hostname (workspace
     pinning, hardware keys, mirror rules). Add one for a new machine.
   - `hypr/host.lua` is gitignored and only holds the monitor lines. Start from
     the template; the Quickshell monitor panel rewrites it for you later:

     ```bash
     cp ~/.config/hypr/host.lua.example ~/.config/hypr/host.lua
     # find outputs/modes with: hyprctl monitors all
     ```

5. Generate the theme once (colours for every app, GTK/Qt themes, wofi's
   stylesheet). Afterwards the theme menu (Super + Ctrl + Space) does this:

   ```bash
   ~/.config/scripts/desktop/theme_apply.sh catppuccin-mocha
   ```

6. Optional: weather and calendar events in the calendar panel and on the bar
   need `quickshell/calendar/.env` (gitignored; copy `.env.example`):
   `WEATHER_LAT`/`WEATHER_LON` for the Open-Meteo forecast, and optionally
   `CALENDAR_ICS_URLS`, e.g. Google Calendar's "Secret address in iCal format".

## Packages

You probably don't want to install this, it's mostly for backup of my own machine but if you
are me in the future this could be quite useful.

`pkglist.txt` and `aurlist.txt` hold the packages I installed on purpose (no
dependencies, no versions), grouped by what they are for:

```bash
grep -v '^#' pkglist.txt | sudo pacman -S --needed -
grep -v '^#' aurlist.txt | paru -S --needed -
```

To refresh them, compare against `pacman -Qqen` / `pacman -Qqem`.

## Hyprland notes

- Config is written in **Hyprland's Lua format (0.55+)**, entry point
  `~/.config/hypr/hyprland.lua`, split into modules under `lua/`
  (`env`, `theme`, `monitors`, `looknfeel`, `animations`, `input`, `rules`,
  `binds`, `plugins`, `hosts`, `autostart`). `hyprctl dispatch` takes Lua too:
  `hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`.
- The terminal for Super + Q is `TERMINAL` in `lua/env.lua`.
- Every bind has a `"Section: what it does"` description; the Guide panel
  (Super + Ctrl + Shift + G) reads them from `hyprctl binds -j`, so it never
  needs updating by hand.
- Everything that talks to the compositor from scripts goes through
  `~/.config/scripts/lib/compositor.sh`. Source it from bash, or run it
  directly (`compositor.sh monitors-json`) from QML/Python.
- Panels are opened over Quickshell IPC: `qs_manager.sh` runs
  `qs -p ~/.config/quickshell/Main.qml ipc call panel command <panel>`
  (`... panel command close`, `... panel active` to see what is open).

## Theming

`scripts/desktop/theme_apply.sh <theme|wallpaper>` reads one palette (a file
from `scripts/desktop/themes/`, or colours matugen derives from the wallpaper)
and writes colours for everything: Hyprland, waybar, swaync, swayosd, wofi,
wlogout, the terminals, Neovim, hyprlock, plus

- a GTK theme `Palette` (adw-gtk3 recoloured) for GTK3/GTK4/libadwaita apps,
- an icon theme `Palette` (Adwaita with folders in the accent colour),
- a qt6ct colour scheme and a KDE colour scheme `Palette` for Qt apps,
- an OBS theme `Palette` (a Yami variant; OBS styles itself),
- the light/dark preference, from the palette's brightness.

Running GTK apps and waybar/swaync update in place; Qt apps on restart.
Apps with their own theme setting need it pointed at the palette once per
machine: Prism Launcher → Settings → Theme "System", OBS → Settings →
Appearance → "Palette", Kdenlive → Settings → Colour Theme → "Palette".
Generated files are gitignored. Applying a wallpaper (picker, Super + Ctrl + W)
re-derives the palette from it through `matugen_apply.sh`.

## Shell

- zsh without a framework: plugins come from the repos/AUR (see `pkglist.txt` /
  `aurlist.txt`) and load after the first prompt, so a new shell starts in
  ~80 ms. Tab completion uses `fzf-tab` when it is installed.
- tmux: new terminals offer a session picker. Snapshots are manual:
  prefix + Ctrl-s saves, prefix + Ctrl-r restores (panes, folders, nvim, and
  `claude`/`opencode` resume their last conversation). Nothing is restored on
  its own, so a fresh boot starts clean.

## Optional extras that aren't in this repo

Nothing breaks without these; the binds or bar modules that use them just do
nothing (or hide).

| What | Used by | Without it |
| --- | --- | --- |
| `~/.local/bin/afk` (lecture capture) | Super + Shift + R, bar module | bind does nothing, module hidden |
| `~/.local/bin/login-bind` | Super + Ctrl + L | bind does nothing |
| `~/Programming/Bash/mullvad-location-switcher` | Super + Ctrl + Shift + I | bind does nothing |
| `/etc/keyd/*.conf` (keyd layers) | Caps "nordic" layer, `mousews` | Caps still types å/ø/æ via altgr-intl |
| Millennium Steam skin | matugen template | template skipped automatically |
| `scrolloverview` (hyprpm) | Super + Tab overview | bind not registered |

## CI

`.github/workflows/nvim-check.yml` runs on every push/PR touching the Neovim
config: installs plugins headlessly, builds the treesitter parsers, and runs a
smoke test (`scripts/ci-check.lua`) that fails the build if the config errors.

## Credits

- Neovim config is practically entirely rewritten, but it grew out of
  Joséan Martinez's setup from back in 2024.
- Waybar custom modules, Wofi/Waybar theming and various scripts are picked up
  from various places and adapted.
- The Quickshell panels started as a fork of the modules in
  [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration)
  and have since been reworked for this setup.
