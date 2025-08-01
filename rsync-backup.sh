# Dotfiles backup script

# Copying the important hyprland files:
mkdir -p $(pwd)/dotfiles/hypr
rsync $HOME/.config/hypr/hyprland.conf $(pwd)/dotfiles/hypr
rsync $HOME/.config/hypr/keybindings.conf $(pwd)/dotfiles/hypr
rsync $HOME/.config/hypr/windowrules.conf $(pwd)/dotfiles/hypr
rsync $HOME/.config/hypr/animations.conf $(pwd)/dotfiles/hypr
rsync $HOME/.config/hypr/hyprlock.conf $(pwd)/dotfiles/hypr
rsync $HOME/.config/hypr/hypridle.conf $(pwd)/dotfiles/hypr

# Alacritty
mkdir -p $(pwd)/dotfiles/alacritty/themes
rsync $HOME/.config/alacritty/alacritty.toml $(pwd)/dotfiles/alacritty
rsync $HOME/.config/alacritty/themes/coolnight.toml $(pwd)/dotfiles/alacritty/themes

# Neofetch (deprecated, will replace with a fastfetch config eventually)
mkdir -p $(pwd)/dotfiles/neofetch
rsync $HOME/.config/neofetch/config.conf $(pwd)/dotfiles/neofetch

# Neovim (Credit to josean that made almost the entire config, I simply added a keybind but I do intend to continue updating this)
rsync -a $HOME/.config/nvim $(pwd)/dotfiles/

# nwg-dock-hyprland
mkdir -p $(pwd)/dotfiles/nwg-dock-hyprland
rsync $HOME/.config/nwg-dock-hyprland/style.css $(pwd)/dotfiles/nwg-dock-hyprland

# Swaync
mkdir -p $(pwd)/dotfiles/swaync
rsync $HOME/.config/swaync/style.css $(pwd)/dotfiles/swaync
rsync $HOME/.config/swaync/config.json $(pwd)/dotfiles/swaync

# Waybar (important one)
mkdir -p $(pwd)/dotfiles/waybar/scripts
rsync $HOME/.config/waybar/style.css $(pwd)/dotfiles/waybar
rsync $HOME/.config/waybar/config.jsonc $(pwd)/dotfiles/waybar
rsync -a $HOME/.config/waybar/scripts $(pwd)/dotfiles/waybar

# Wofi
mkdir -p $(pwd)/dotfiles/wofi
rsync -a $HOME/.config/wofi $(pwd)/dotfiles

# wlogout
mkdir -p $(pwd)/dotfiles/wlogout
rsync -a $HOME/.config/wlogout $(pwd)/dotfiles

# .zshrc
rsync $HOME/.zshrc $(pwd)/dotfiles

# .tmux.conf
rsync $HOME/.tmux.conf $(pwd)/dotfiles

# arch packages
pacman -Q > $(pwd)/dotfiles/pacman-list.txt

echo "$(date): Finished copying scripts for this week" >> latest.log


# git add .
# git commit -m "Weekly dotfiles backup"
# git push

echo "$(date): Finished pushing dotfiles to github" >> latest.log
