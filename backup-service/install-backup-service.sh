SERVICE_NAME="dotfiles-backup"

echo "\n██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
                      backup-install script                  "

cat <<'EOF'
  _         _        _ _              _      _   
 (_)_ _  __| |_ __ _| | |  ___ __ _ _(_)_ __| |_ 
 | | ' \(_-<  _/ _` | | | (_-</ _| '_| | '_ \  _|
 |_|_||_/__/\__\__,_|_|_| /__/\__|_| |_| .__/\__|
          github.com/filip-rs        |_|        
EOF

echo "\n\n\n"

sleep 1

echo "Installing the systemd service files..."
mkdir $HOME/Services
sudo ln -s $(pwd)/dotfiles-backup.timer /etc/systemd/system/$SERVICE_NAME.timer
sudo ln -s $(pwd)/dotfiles-backup.service /etc/systemd/system/$SERVICE_NAME.service


echo "Starting the systemd timer..."
sudo systemctl enable $SERVICE_NAME.timer
sudo systemctl start $SERVICE_NAME.timer
sudo systemctl daemon-reload

echo "\n\n\n"
echo "Here is the status of the timer:"
sudo systemctl list-timers $SERVICE_NAME.timer
