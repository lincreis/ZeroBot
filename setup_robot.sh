#!/bin/bash

# Exit on any error
set -e

echo "Starting robot setup..."

# Step 1: Update and upgrade the system
sudo apt-get update
sudo apt-get upgrade -y

# Step 2: Install prerequisites
sudo apt-get install -y pigpio apache2 cmake libjpeg62-turbo-dev git curl

# Step 3: Install Node.js 14.17.0 via unofficial builds
echo "Installing Node.js 14.17.0 (ARMv6 compatible)..."
cd ~
wget https://unofficial-builds.nodejs.org/download/release/v14.17.0/node-v14.17.0-linux-armv6l.tar.xz
tar -xJf node-v14.17.0-linux-armv6l.tar.xz
sudo rm node-v14.17.0-linux-armv6l.tar.xz
sudo mv node-v14.17.0-linux-armv6l /usr/local/node
sudo ln -sf /usr/local/node/bin/node /usr/local/bin/node
sudo ln -sf /usr/local/node/bin/npm /usr/local/bin/npm

# Step 4: Clone your GitHub fork
echo "Cloning ZeroBot repository..."
cd ~
git clone https://github.com/lincreis/ZeroBot.git
cd ZeroBot

# Step 5: Install Node.js dependencies using package-lock.json
echo "Installing npm dependencies and generating package-lock.json..."
npm ci

# Step 6: Install mjpg-streamer
echo "Installing mjpg-streamer..."
cd ~
git clone https://github.com/jacksonliam/mjpg-streamer.git ~/mjpg-streamer
cd mjpg-streamer/mjpg-streamer-experimental
make clean all
sudo mkdir /opt/mjpg-streamer
sudo mv * /opt/mjpg-streamer

# Step 7: Enable I2C and Camera (for ADS1115 and raspistill)
echo "Enabling I2C and Camera interfaces..."
sudo raspi-config nonint do_i2c 0  # Enable I2C
sudo raspi-config nonint do_camera 0  # Enable Camera

# Step 8: Update rc.local for autostart
echo "Configuring rc.local for autostart..."
RC_LOCAL="/etc/rc.local"
START_STREAM="/bin/bash /home/pi/ZeroBot/start_stream.sh &"
NODE_APP="sudo /usr/local/node/bin/node /home/pi/ZeroBot/app.js &"
# Backup rc.local
sudo cp $RC_LOCAL $RC_LOCAL.bak
# Remove existing exit 0, add commands, then re-add exit 0
sudo sed -i '/exit 0/d' $RC_LOCAL
echo "$START_STREAM" | sudo tee -a $RC_LOCAL > /dev/null
echo "$NODE_APP" | sudo tee -a $RC_LOCAL > /dev/null
echo "exit 0" | sudo tee -a $RC_LOCAL > /dev/null

# --- Optional: Expand Filesystem (if needed) ---
sudo raspi-config nonint do_expand_rootfs
# --- Optional: Autologin to console on user pi
sudo raspi-config nonint do_boot_behaviour B2

# Step 10: Reboot to apply changes
echo "Setup complete! Rebooting in 5 seconds..."
sleep 5
sudo reboot