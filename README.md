# Arch dotfiles

Repository containing my (most important) arch linux dotfies. Full of configs and settings I use on a daily basis. The dotfiles are located in the dotfiles folder, wheras the root of the repository contains systemd service and timer files for automatically copying the dotfiles and backing them up on a set schedule. If you simply want to download and install the files I would recommend cloning the repo and running the `bash ./dotfiles-installer.sh` which will copy the correct files to the correct locations automatically.

# Script Installation Guide

I've made a simple script that automates the process of setting up the config files, but I only recommend to use this if you are on a fresh system or don't mind your files being overwritten.

## ALWAYS TAKE BACKUP BEFOREHAND

1. Clone the repository:

   ```bash
   git clone https://github.com/filip-rs/arch-dotfiles.git
   ```

   Alternatively clone using the ssh feature:

   ```bash
   git clone git@github.com:filip-rs/arch-dotfiles.git
   ```

2. Navigate into the project directory:

   ```bash
   cd arch-dotfiles
   ```

3. Run the install script:

   ```bash
   ./dotfiles-install.sh
   ```

4. Done :)

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

# Backup script installation

The repository also contains a script for automatic backup of dotfiles, including systemd service and timer files to handle this automatically. There is a bash script for easy install but I will also provide a manual install guide incase the automatic one fails or you simply want more control over the installtion process.

## Installation script

1. Make sure you are in the correct directory:

```bash
cd backup-service
pwd
```

Should return `bash .../arch-dotfiles/backup-service`

2. Run the install script (Requires sudo to copy files into /etc folder)

```bash
sudo ./install-backup-service.sh
```

3. Modify the `bash dotfiles-backup.service`:
   This file has to contain the specific path to the repository.

```bash
nvim dotfiles-backup.service
```

Update the `bash WorkingDirectory=/home/filip/Services` so it points to where you have the repository located.

## Manual install

1. Make sure you are in the correct directory:

```bash
cd backup-service
pwd
```

Should return `bash .../arch-dotfiles/backup-service`

2. Symlink the timers:

```bash
sudo ln -s dotfiles-backup.timer /etc/systemd/system/dotfiles-backup.timer
sudo ln -s dotfiles-backup.service /etc/systemd/system/dotfiles-backup.service
```

3. Modify the `bash dotfiles-backup.service`:
   This file has to contain the specific path to the repository.

```bash
nvim dotfiles-backup.service
```

Update the `bash WorkingDirectory=/home/filip/Services` so it points to where you have the repository located.

4. Enable the timer:

   ```bash
   sudo systemctl enable dotfiles-backup.timer
   ```

5. Reload systemd daemon
   ```bash
   sudo systemctl daemon-reload
   ```
