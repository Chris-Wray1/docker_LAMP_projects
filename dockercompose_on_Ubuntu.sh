#!/bin/bash
clear
echo "[+] Preparing to install"
sudo apt update > /dev/null 2>& 1

# Add the Docker Repository
echo "[+] Adding the Docker Repository"
sudo apt install -y --reinstall wget ca-certificates > /dev/null 2>& 1
sudo install -m 0755 -d /etc/apt/keyrings > /dev/null 2>& 1
sudo wget -O /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg > /dev/null 2>& 1

# Add the Docker Sources File
sudo echo -e "X-Repolib-Name: Docker
Enabled: yes
Types: deb
Architectures: amd64
URIs: https://download.docker.com/linux/ubuntu/
Signed-By: /etc/apt/keyrings/docker.asc
Suites: noble
Components: stable" > /etc/apt/sources.list.d/docker.sources

# Install initial docker environment, then disable to allow Docker-Desktop
echo "  [+] Installing the Docker Environment"
sudo apt install -y --reinstall docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras uidmap dbus-user-session > /dev/null 2>& 1
echo "  [+] Prepare Docker for Docker Desktop"
sudo systemctl disable --now docker.service docker.socket > /dev/null 2>& 1
sudo rm /var/run/docker.sock > /dev/null 2>& 1

# Ensure that the docker group and user privileges are assigned
echo "  [+] Configure Docker User & Group"
sudo groupadd docker > /dev/null 2>& 1
sudo usermod -aG docker $USER > /dev/null 2>& 1
newgrp docker > /dev/null 2>& 1

# Enable Rootless Docker 
echo "[+] Enabling the Docker Rootless Environment"
cd /usr/bin
./dockerd-rootless-setuptool.sh install

# Download and install Docker-Desktop
echo "[+] Downloading Docker Desktop"
cd ~/Downloads
wget https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
echo "  [+] Installing Docker Desktop"
sudo apt install -y --reinstall ./docker-desktop-amd64.deb > /dev/null 2>& 1

# Create New Script to launch Docker-Desktop
echo "  [+] Updating the Docker Desktop shortcut"
sudo mkdir -p /usr/share/scripts > /dev/null 2>& 1
sudo echo -e "#!/bin/bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
/opt/docker-desktop/bin/docker-desktop" > /usr/share/scripts/docker-desktop
sudo chmod -R 0777 /usr/share/scripts
sudo chmod +x /usr/share/scripts/docker-desktop

# Ensure the system can find the new script
if ! grep -q "/usr/share/scripts" /etc/environment; then
	read -r environment < /etc/environment
	environment=${environment#PATH=\"} # strip quotes
	environment="PATH=\"/usr/share/scripts:${environment}"
	sudo echo -e "${environment}" > /etc/environment
fi

# Update the desktop file
sudo echo -e "[Desktop Entry]
Name=Docker Desktop
Comment=Docker Desktop for Linux
Exec=/usr/share/scripts/docker-desktop
#Exec=/opt/docker-desktop/bin/docker-desktop
Icon=/opt/docker-desktop/share/icon.original.png
Type=Application
Keywords=container;docker;
Categories=Development;" > /usr/share/applications/docker-desktop.desktop
