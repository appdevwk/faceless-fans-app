#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Directory Variables
BASE_DIR="$HOME/faceless-fans-project"
BACKEND_DIR="$BASE_DIR/backend"
FRONTEND_DIR="$BASE_DIR/frontend"
BACKEND_GITHUB_USER="appdevwk"
BACKEND_GITHUB_REPO="faceless-fans-backend"
FRONTEND_GITHUB_USER="appdevwk"
FRONTEND_GITHUB_REPO="faceless-fans-frontend"

echo -e "${GREEN}Starting combined setup for Faceless Fans at 03:30 PM EDT, July 20, 2025...${NC}"

# 1. Update system (run with sudo)
echo -e "${GREEN}Updating system...${NC}"
sudo apt-get update

# 2. Install Node.js manually for Kali compatibility
echo -e "${GREEN}Installing Node.js and npm manually...${NC}"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -
sudo apt-get install -y nodejs

# 3. Install other dependencies (run with sudo)
echo -e "${GREEN}Installing additional dependencies...${NC}"
sudo apt-get install -y curl git mongodb-server

# 4. Create root package.json with build scripts
echo -e "${GREEN}Creating root package.json with build scripts...${NC}"
mkdir -p "$BASE_DIR" && cd "$BASE_DIR"
cat << 'EOF' > package.json
{
  "name": "faceless-fans-project",
  "version": "1.0.0",
  "scripts": {
    "build": "npm run build:backend && npm run build:frontend",
    "build:backend": "cd backend && npm install && npm run build",
    "build:frontend": "cd frontend && npm install && npm run build",
    "start": "cd backend && node server.js"
  },
  "private": true
}
EOF

# --- Backend Setup ---

echo -e "${GREEN}Setting up backend in
