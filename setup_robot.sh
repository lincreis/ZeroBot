#!/bin/bash

# Exit on any error
set -e

echo "Starting robot setup..."

# Step 1: Update and upgrade the system
sudo apt-get update
sudo apt-get upgrade -y

# Step 2: Install prerequisites
sudo apt-get install -y apache2 cmake libjpeg62-turbo-dev git curl

# Step 3: Install Node.js 14.17.0 via NodeSource
echo "Installing Node.js 14.17.0 (ARMv6 compatible)..."
curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Step 4: Clone your GitHub fork
echo "Cloning ZeroBot repository..."
cd ~
git clone https://github.com/lincreis/ZeroBot.git
cd ZeroBot

# Step 5: Install Node.js dependencies using package-lock.json
echo "Installing npm dependencies and generating package-lock.json..."
npm install --save-exact express socket.io node-ads1x15@1.0.1 pigpio
npm ci

# Step 6: Install mjpg-streamer
echo "Installing mjpg-streamer..."
cd ~
git clone https://github.com/jacksonliam/mjpg-streamer.git mjpg-streamer
cd mjpg-streamer/mjpg-streamer-experimental
make clean all
sudo mkdir -p /opt/mjpg-streamer
sudo mv * /opt/mjpg-streamer

# Step 7: Enable I2C and Camera (for ADS1115 and raspistill)
echo "Enabling I2C and Camera interfaces..."
sudo raspi-config nonint do_i2c 0  # Enable I2C
sudo raspi-config nonint do_camera 0  # Enable Camera

# Step 8: Create start_stream.sh if not in repo
if [ ! -f start_stream.sh ]; then
  echo "Creating start_stream.sh..."
  cat << 'EOF' > start_stream.sh
#!/bin/bash
/opt/mjpg-streamer/mjpg_streamer -i "input_raspicam.so -fps 15 -q 80" -o "output_http.so -p 8080 -w /opt/mjpg-streamer/www" &
EOF
  chmod +x start_stream.sh
fi

# Step 9: Update rc.local for autostart
echo "Configuring rc.local for autostart..."
RC_LOCAL="/etc/rc.local"
START_STREAM="bash /home/pi/ZeroBot/start_stream.sh &"
NODE_APP="/usr/bin/node /home/pi/ZeroBot/app.js &"
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