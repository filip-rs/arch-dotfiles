# Arch dotfiles

Repository containing my (most important) arch linux dotfies. Full of configs and settings I use on a daily basis. The dotfiles are located in the dotfiles folder, wheras the root of the repository contains systemd service and timer files for automatically copying the dotfiles and backing them up on a set schedule. If you simply want to download and install the files I would recommend cloning the repo and running the `./dotfiles-install.sh` which will copy the correct files to the correct locations automatically.

# Script Installation Guide

I've made a simple script that automates the process of setting up the config files, but I only recommend to use this if you are on a fresh system or don't mind your files being overwritten.

## ALWAYS TAKE BACKUP BEFOREHAND

1. Clone the repository:

   ```bash
   git clone https://github.com/filip-rs/arch-dotfiles.git
   ```

2. Navigate into the project directory:

   ```bash
   cd arch-dotfiles/dotfiles
   ```

3. Install the dotfiles with stow

   ```bash
   stow . --dotfiles -t $HOME
   ```

4. \[Optional\] Install desktopentries
   ```bash
   cd desktopentries \
   sudo stow . -t /usr/share/applications
   ```

## Manual install guide:

1. Clone the repository:

   ```bash
   git clone https://github.com/filip-rs/arch-dotfiles.git
   ```

   Alternatively clone using the ssh feature:

   ```bash
   git clone git@github.com:filip-rs/arch-dotfiles.git
   ```

2. Navigate into the dotfiles directory:

   ```bash
   cd arch-dotfiles/dotfiles
   ```

3. Manually copy the folders to their correct locations:

```bash
cp -r hypr ~/.config
cp -r alacritty ~/.config
cp -r nvim ~/.config
cp -r waybar ~/.config
cp -r nwg-dock-hyprland ~/.config
cp -r zsh ~/.config
cp -r wofi ~/.config
cp -r neofetch ~/.config
etc. etc.
```
