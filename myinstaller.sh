#!/bin/sh

# =========================================================================
# One-liner execution command:
# wget -qO - https://raw.githubusercontent.com/popking159/MyStreamer/refs/heads/main/myinstaller.sh | /bin/sh
# =========================================================================

PLUGIN_NAME="MyStreamer"
PKG_BASE="enigma2-plugin-extensions-mystreamer"
VERSION="1.0.0"
USERNAME="popking159"
REPO="MyStreamer"
ARCH_TARGET="all"

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Workspace paths
TMP_DIR="/var/volatile/tmp"
[ -d "$TMP_DIR" ] || TMP_DIR="/tmp"

PKG_MANAGER=""

log() {
    # Automatically colorize based on the log tag
    case "$1" in
        *\[INFO\]*) echo -e "${CYAN}$1${NC}" ;;
        *\[OK\]*) echo -e "${GREEN}$1${NC}" ;;
        *\[WARN\]*) echo -e "${YELLOW}$1${NC}" ;;
        *\[ERROR\]*) echo -e "${RED}$1${NC}" ;;
        *) echo -e "$1" ;;
    esac
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}         $PLUGIN_NAME IPK INSTALLER                 ${NC}"
echo -e "${GREEN}                  by MNASR                          ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. Detect Package Manager
if has_cmd opkg; then
    PKG_MANAGER="opkg"
elif has_cmd apt-get; then
    PKG_MANAGER="apt"
else
    log "[ERROR] No supported package manager (opkg/apt) found!"
    exit 1
fi
log "[INFO] Package manager detected: ${PKG_MANAGER}"

# 2. Construct Universal IPK File Name and Download URL
IPK_NAME="${PKG_BASE}_${VERSION}_${ARCH_TARGET}.ipk"
PLUGIN_URL="https://github.com/${USERNAME}/${REPO}/raw/refs/heads/main/${IPK_NAME}"
TMP_FILE="$TMP_DIR/$IPK_NAME"

log "[INFO] Target Package: $IPK_NAME"

# 3. Download IPK Archive safely (Catch GitHub 404 HTML pages)
log "[INFO] Downloading IPK package..."
rm -f "$TMP_FILE"

if has_cmd wget; then
    wget -q --no-check-certificate "$PLUGIN_URL" -O "$TMP_FILE"
elif has_cmd curl; then
    curl -s -k -L "$PLUGIN_URL" -o "$TMP_FILE"
fi

if [ ! -s "$TMP_FILE" ] || grep -q -i "<html" "$TMP_FILE" || grep -q "404: Not Found" "$TMP_FILE"; then
    log "[ERROR] Download failed! The package $IPK_NAME does not exist on GitHub."
    rm -f "$TMP_FILE"
    exit 1
fi

# 4. Install the IPK
log "[INFO] Installing package..."
if [ "$PKG_MANAGER" = "opkg" ]; then
    opkg install --force-reinstall --force-overwrite "$TMP_FILE"
elif [ "$PKG_MANAGER" = "apt" ]; then
    dpkg -i "$TMP_FILE"
    apt-get install -f -y
fi

if [ $? -ne 0 ]; then
    log "[ERROR] Installation failed!"
    rm -f "$TMP_FILE"
    exit 1
fi

# 5. Cleanup and Finalize
rm -f "$TMP_FILE"
sync

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}          $PLUGIN_NAME INSTALLATION COMPLETE        ${NC}"
echo -e "${GREEN}====================================================${NC}"
log "[OK] Universal plugin installed successfully."

exit 0
