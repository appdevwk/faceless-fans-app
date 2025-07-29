#!/bin/bash
set -e

# === CONFIGURATION ===
# Set SRC to the path of your original Faceless Fans project files.
# Use SRC="${PWD}" if running this script from the source project directory.
SRC="${PWD}"  # Or: SRC="/path/to/faceless-fans-app"
DST="/home/whiteknight/ext4files/faceless"
VENV="$DST/venv"

echo "---------------------------------------------"
echo "Faceless Fans Project: Copy & venv Setup"
echo "---------------------------------------------"
echo "[*] Copying project files from $SRC to $DST"

# 1. Ensure your destination exists
mkdir -p "$DST"

# 2. Copy your project files into the new directory, excluding unwanted folders/files
rsync -av --exclude 'node_modules' --exclude 'uploads' --exclude '.env' "$SRC/" "$DST/"

# 3. Create a Python virtual environment
if ! command -v python3 &>/dev/null; then
  echo "Python3 is required but not found!"
  exit 1
fi

if [ ! -d "$VENV" ]; then
    echo "[*] Creating Python venv at $VENV"
    python3 -m venv "$VENV"
else
    echo "[*] Python venv already exists at $VENV"
fi

echo "[*] To activate your venv, run:"
echo "    source $VENV/bin/activate"

# 4. Optionally install requirements.txt if you have one
REQ_FILE="$DST/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    source "$VENV/bin/activate"
    echo "[*] Installing Python requirements..."
    pip install -r "$REQ_FILE"
    deactivate
fi

echo "[*] All set! Your Faceless Fans app files are in $DST and your venv is at $VENV"
