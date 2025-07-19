#!/bin/bash

# === Obliterator DEB Builder ===
set -e

echo "🛠 Preparing obliterator DEB package..."

# Variables
PKG_NAME="obliterator"
VERSION="1.0"
BUILD_DIR="${PKG_NAME}_${VERSION}"
INSTALL_PATH="/usr/local/bin"

# Step 1: Create folder structure
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR$INSTALL_PATH"

# Step 2: Create control file
cat > "$BUILD_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: xsCyber
Description: A full system-level tool remover with interactive terminal interface.
EOF

# Step 3: Write the obliterator script into the correct place
cat > "$BUILD_DIR$INSTALL_PATH/obliterator" <<'EOL'
#!/bin/bash

# === Obliterator by xsCyber ===

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m"

clear
echo -e "${RED}"
cat << "EOF"
   ___  _ _ _             _       _             
  / _ \| | | |_ _ _  _ __| |___ _| |_ ___ _ _ ___
 | (_) | | |  _| ' \| '_ \ / -_) _|  _/ _ \ '_(_-<
  \___/|_|_|\__|_||_| .__/_\___\__|\__\___/_| /__/
                    |_|    by xsCyber (Obliterator)
EOF
echo -e "${NC}"
echo -e "${CYAN}Obliterator removes tools completely: files, services, logs, users.${NC}\n"

# Basic input using whiptail-style logic
read -p "🔧 Enter the tool name to remove: " tool
[[ -z "$tool" ]] && echo -e "${RED}❌ No tool entered. Exiting.${NC}" && exit 1

# Suggest similar
echo -e "${YELLOW}🔍 Searching for similar commands...${NC}"
compgen -c "$tool" | sort -u | head -5

# Confirm
read -p "❗ Type the tool name again to confirm: " confirm
[[ "$confirm" != "$tool" ]] && echo -e "${RED}❌ Cancelled.${NC}" && exit 1

# Optional mode
read -p "🔥 Deep removal mode? (y/n): " deep_mode
[[ "$deep_mode" == "y" || "$deep_mode" == "Y" ]] && deep=true || deep=false

log="/tmp/obliterator_${tool}_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$log") 2>&1

echo -e "${CYAN}🚀 Removing '$tool'...\n${NC}"

# APT
if dpkg -l | grep -qw "$tool"; then
    sudo apt purge --auto-remove -y "$tool"
fi

# Services
sudo systemctl stop "$tool" 2>/dev/null
sudo systemctl disable "$tool" 2>/dev/null

# Paths
paths=(
  "/opt/$tool" "/etc/$tool" "/var/log/$tool"
  "/usr/share/$tool" "/usr/bin/$tool"
  "/usr/local/bin/$tool"
)

for path in "${paths[@]}"; do
  [[ -e "$path" ]] && echo -e "${RED}[DEL] $path${NC}" && sudo rm -rf "$path"
done

# Deep mode
if [[ "$deep" == true ]]; then
  sudo find / -type f -iname "*$tool*" -exec rm -f {} \; 2>/dev/null
  sudo find / -type d -iname "*$tool*" -exec rm -rf {} \; 2>/dev/null
fi

# Users
sudo userdel "$tool" 2>/dev/null
sudo groupdel "$tool" 2>/dev/null
sudo systemctl daemon-reload
sudo updatedb

echo -e "\n${GREEN}✅ '$tool' obliterated.${NC}"
echo -e "${CYAN}📝 Log: $log${NC}"
EOL

# Make it executable
chmod +x "$BUILD_DIR$INSTALL_PATH/obliterator"

# Step 4: Build the DEB package
dpkg-deb --build "$BUILD_DIR" > /dev/null

echo -e "\n🎉 Done! Package created: ${GREEN}${BUILD_DIR}.deb${NC}"
