# Dotfiles backup script
set -x

# Copying the important hyprland files:
mkdir -p $(pwd)/dotfiles/hypr
cp $HOME/.config/hypr/hyprland.conf $(pwd)/dotfiles/hypr
cp $HOME/.config/hypr/keybindings.conf $(pwd)/dotfiles/hypr
cp $HOME/.config/hypr/windowrules.conf $(pwd)/dotfiles/hypr
cp $HOME/.config/hypr/animations.conf $(pwd)/dotfiles/hypr

# Alacritty
mkdir -p $(pwd)/dotfiles/alacritty
cp $HOME/.config/alacritty/alacritty.toml $(pwd)/dotfiles/alacritty
cp $HOME/.config/alacritty/themes/coolnight.toml $(pwd)/dotfiles/alacritty/themes

# Neofetch (deprecated, will replace with a fastfetch config eventually)
mkdir -p $(pwd)/dotfiles/neofetch
cp $HOME/.config/neofetch/config.conf $(pwd)/dotfiles/neofetch

# Neovim (Credit to josean that made almost the entire config, I simply added a keybind but I do intend to continue updating this)
cp -r $HOME/.config/nvim $(pwd)/dotfiles/

# nwg-dock-hyprland
mkdir -p $(pwd)/dotfiles/nwg-dock-hyprland
cp $HOME/.config/nwg-dock-hyprland/style.css $(pwd)/dotfiles/nwg-dock-hyprland

# Swaync
mkdir -p $(pwd)/dotfiles/swaync
cp $HOME/.config/swaync/style.css $(pwd)/dotfiles/swaync
cp $HOME/.config/swaync/config.json $(pwd)/dotfiles/swaync

# Waybar (important one)
mkdir -p $(pwd)/dotfiles/waybar/scripts
cp $HOME/.config/waybar/style.css $(pwd)/dotfiles/waybar
cp $HOME/.config/waybar/config.jsonc $(pwd)/dotfiles/waybar
cp -r $HOME/.config/waybar/scripts $(pwd)/dotfiles/waybar

# Wofi
mkdir -p $(pwd)/dotfiles/wofi
cp -r $HOME/.config/wofi $(pwd)/dotfiles

# wlogout
mkdir -p $(pwd)/dotfiles/wlogout
cp -r $HOME/.config/wlogout $(pwd)/dotfiles

echo "$(date): Finished copying scripts for this week" >> latest.log


git add .
git commit -m "Weekly dotfiles backup"
git push

echo "$(date): Finished pushing dotfiles to github" >> latest.log
