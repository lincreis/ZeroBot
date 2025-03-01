#!/bin/bash

# Change to the repo directory
cd /home/pi/ZeroBot

# Pull latest changes from GitHub
git pull origin main

# Check if package-lock.json changed
if git diff-tree --name-only HEAD^ HEAD | grep -q "package-lock.json"; then
  echo "package-lock.json changed, updating dependencies..."
  npm ci
fi

# Restart app.js
sudo pkill node
sudo node app.js &