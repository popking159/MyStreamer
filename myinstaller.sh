#!/bin/sh

# =========================================================================
# One-liner execution command:
# wget -qO - https://raw.githubusercontent.com/popking159/MyStreamer/refs/heads/main/myinstaller.sh | /bin/sh
# =========================================================================

PLUGIN_NAME="MyStreamer"
PKG_BASE="enigma2-plugin-extensions-mystreamer"
VERSION="1.0.1"
USERNAME="popking159"
REPO="MyStreamer"

PLUGIN_PATH="/usr/lib/enigma2/python/Plugins/Extensions/MyStreamer"

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
PYTHON_VERSION=""
PY_VER=""
ARCH=""

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

# 2. Check and Remove Previous Version
log "[INFO] Checking for previous installations..."
OLD_INSTALLED=0

if [ "$PKG_MANAGER" = "opkg" ]; then
    if opkg status "$PKG_BASE" 2>/dev/null | grep -q "^Status:.*installed"; then
        log "[WARN]    -> Old package version detected. Uninstalling via opkg..."
        opkg remove "$PKG_BASE" --force-depends >/dev/null 2>&1
        OLD_INSTALLED=1
    fi
elif [ "$PKG_MANAGER" = "apt" ]; then
    if dpkg-query -W -f='${Status}' "$PKG_BASE" 2>/dev/null | grep -q "install ok installed"; then
        log "[WARN]    -> Old package version detected. Uninstalling via apt..."
        apt-get remove -y "$PKG_BASE" >/dev/null 2>&1
        OLD_INSTALLED=1
    fi
fi

if [ -d "$PLUGIN_PATH" ]; then
    log "[WARN]    -> Old plugin directory detected. Removing..."
    rm -rf "$PLUGIN_PATH"
    OLD_INSTALLED=1
fi

if [ $OLD_INSTALLED -eq 1 ]; then
    log "[OK]    -> Uninstallation of previous version complete."
else
    log "[INFO]    -> No previous version found."
fi

# 3. Detect Python Version (Formatted with decimal, e.g., 3.13)
if has_cmd python3; then
    PYTHON_VERSION="3"
    PY_VER=$(python3 -c 'import sys; print("%d.%d" % (sys.version_info.major, sys.version_info.minor))' 2>/dev/null)
elif has_cmd python; then
    PYTHON_VERSION="2"
    PY_VER=$(python -c 'import sys; print("%d.%d" % (sys.version_info.major, sys.version_info.minor))' 2>/dev/null)
fi

# Fallback for Python version from enigma.info
if [ -z "$PY_VER" ] && [ -f /usr/lib/enigma.info ]; then
    PY_VER_RAW=$(grep "^python=" /usr/lib/enigma.info | cut -d"=" -f2 | tr -d "'\"")
    if [ -n "$PY_VER_RAW" ]; then
        # Extract just the Major.Minor parts (e.g., 3.14.1 -> 3.14)
        PY_VER=$(echo "$PY_VER_RAW" | cut -d"." -f1,2)
    fi
fi

log "[INFO] Detected Python Version: Python $PY_VER"

# 4. Detect STB Architecture
if [ -f /usr/lib/enigma.info ]; then
    INFO_ARCH=$(grep "^architecture=" /usr/lib/enigma.info | cut -d"=" -f2 | tr -d "'\"")
    case "$INFO_ARCH" in
        cortexa15hf-neon-vfpv4|armv7ahf-neon|aarch64|mips32el)
            ARCH="$INFO_ARCH"
            ;;
    esac
fi

if [ -z "$ARCH" ] && [ -f /etc/opkg/arch.conf ]; then
    if grep -q "cortexa15hf-neon-vfpv4" /etc/opkg/arch.conf; then
        ARCH="cortexa15hf-neon-vfpv4"
    elif grep -q "armv7ahf-neon" /etc/opkg/arch.conf; then
        ARCH="armv7ahf-neon"
    elif grep -q "aarch64" /etc/opkg/arch.conf; then
        ARCH="aarch64"
    elif grep -q "mips32el" /etc/opkg/arch.conf; then
        ARCH="mips32el"
    fi
fi

if [ -z "$ARCH" ]; then
    UNAME_M=$(uname -m)
    case "$UNAME_M" in
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        armv7l|arm*)
            ARCH="cortexa15hf-neon-vfpv4"
            ;;
        mips*|mipsel)
            ARCH="mips32el"
            ;;
    esac
fi

log "[INFO] Detected Architecture: ${ARCH:-Unknown}"

# Verify supported arch and python
case "$ARCH" in
    cortexa15hf-neon-vfpv4|armv7ahf-neon|aarch64|mips32el)
        ;;
    *)
        log "[ERROR] Unsupported STB architecture: '$ARCH'. Aborting installation."
        exit 1
        ;;
esac

case "$PY_VER" in
    3.13|3.14)
        ;;
    *)
        log "[ERROR] Detected Python version is $PY_VER. MyStreamer only supports Python 3.13 or 3.14!"
        exit 1
        ;;
esac

# 5. Construct IPK File Name and GitLab Download URL
IPK_NAME="${PKG_BASE}_${VERSION}_${ARCH}_py${PY_VER}.ipk"
PLUGIN_URL="https://gitlab.com/${USERNAME}/${REPO}/-/raw/main/${IPK_NAME}"
TMP_FILE="$TMP_DIR/$IPK_NAME"

log "[INFO] Target Package: $IPK_NAME"

# 6. Download IPK Archive safely (Catch GitLab 404 HTML pages)
log "[INFO] Downloading IPK package..."
rm -f "$TMP_FILE"

if has_cmd wget; then
    wget -q --no-check-certificate "$PLUGIN_URL" -O "$TMP_FILE"
elif has_cmd curl; then
    curl -s -k -L "$PLUGIN_URL" -o "$TMP_FILE"
fi

if [ ! -s "$TMP_FILE" ] || grep -q -i "<html" "$TMP_FILE" || grep -q "404 Not Found" "$TMP_FILE"; then
    log "[ERROR] Download failed! The compiled package for $ARCH and Python $PY_VER does not exist on GitLab."
    log "[ERROR] URL Checked: $PLUGIN_URL"
    rm -f "$TMP_FILE"
    exit 1
fi

# 7. Install the IPK
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

# 8. Cleanup and Finalize
rm -f "$TMP_FILE"
sync

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}          $PLUGIN_NAME INSTALLATION COMPLETE        ${NC}"
echo -e "${GREEN}====================================================${NC}"
log "[OK] Installed successfully for $ARCH (Python $PY_VER)."

exit 0
