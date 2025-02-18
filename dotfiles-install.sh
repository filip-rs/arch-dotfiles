SERVICE_NAME="dotfiles-backup"

echo "\n██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
                                                             "

cat <<'EOF'
  _         _        _ _              _      _   
 (_)_ _  __| |_ __ _| | |  ___ __ _ _(_)_ __| |_ 
 | | ' \(_-<  _/ _` | | | (_-</ _| '_| | '_ \  _|
 |_|_||_/__/\__\__,_|_|_| /__/\__|_| |_| .__/\__|
          github.com/filip-rs        |_|        
EOF

echo "\n\n\n"

sleep 1


echo "Copying alacritty config..."
cp -r $(pwd)/dotfiles/alacritty $HOME/.config

echo "Copying hyprland config..."
cp -r $(pwd)/dotfiles/hypr $HOME/.config

echo "Copying neofetch config..."
cp -r $(pwd)/dotfiles/neofetch $HOME/.config

echo "Copying neovim config..."
cp -r $(pwd)/dotfiles/nvim $HOME/.config

echo "Copying nwg-dock config..."
cp -r $(pwd)/dotfiles/nwg-dock-hyprland $HOME/.config

echo "Copying swaync config..."
cp -r $(pwd)/dotfiles/swaync $HOME/.config

echo "Copying waybar config..."
cp -r $(pwd)/dotfiles/waybar $HOME/.config

echo "Copying wofi config..."
cp -r $(pwd)/dotfiles/wofi $HOME/.config
