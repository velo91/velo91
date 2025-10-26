#!/bin/bash
# ==========================================
# MetaTrader 5 Full Installer
# Ubuntu / Kubuntu Compatible
#
# Run this command with NO sudo:
# cd ~
# nano mt5-ubuntu-installer.sh
# chmod +x mt5-ubuntu-installer.sh
# ./mt5-ubuntu-installer.sh
#
# Open KDE Menu Editor
# Click New Item
# Name=Close All MT5
# Comment=Force close all MetaTrader 5 instances (Wine)
# Environment Variables=WINEPREFIX=/home/ideapad/.mt5
# Program=wineserver
# Command-Line Arguments=-k
# Set Custom Icon
# Save
# ==========================================

set -e

URL_MT5="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
URL_WEBVIEW="https://go.microsoft.com/fwlink/p/?LinkId=2124703"
WINE_VERSION="stable"
WINEPREFIX="$HOME/.mt5"
GECKO_VERSION="2.47.4"
GECKO_URL="https://dl.winehq.org/wine/wine-gecko/$GECKO_VERSION/wine-gecko-$GECKO_VERSION-x86_64.msi"

echo "=========================================="
echo "MetaTrader 5 Installer"
echo "Prefix  : $WINEPREFIX"
echo "Windows : 10"
echo "=========================================="

sudo apt update -y
sudo apt install -y wget curl gnupg software-properties-common cabextract lsb-release winbind bc winetricks

# Add WineHQ repo
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -q -O - https://dl.winehq.org/wine-builds/winehq.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key
DISTRO=$(lsb_release -cs)
sudo wget -NP /etc/apt/sources.list.d/ \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/$DISTRO/winehq-$DISTRO.sources" || true
sudo apt update
sudo apt install --install-recommends -y winehq-$WINE_VERSION

# Create prefix
echo "[1/9] Initializing Wine prefix (64-bit)..."
rm -rf "$WINEPREFIX"
WINEARCH=win64 WINEPREFIX=$WINEPREFIX wineboot --init >/dev/null 2>&1
sleep 2

# Force Windows 10
echo "[2/9] Setting Windows version to 10..."
cat > "$WINEPREFIX/user.reg" <<EOF
[Software\\\\Wine\\\\Wine\\\\Config]
"Version"="win10"
EOF

# Install Gecko
echo "[3/9] Installing Wine Gecko $GECKO_VERSION..."
wget -q -O /tmp/wine-gecko.msi "$GECKO_URL"
WINEPREFIX=$WINEPREFIX wine msiexec /i /tmp/wine-gecko.msi /quiet || true

# Core fonts and dependencies
echo "[4/9] Installing corefonts, msxml, gdiplus, runtimes..."
WINEPREFIX=$WINEPREFIX winetricks -q corefonts
WINEPREFIX=$WINEPREFIX winetricks -q msxml3 msxml6 gdiplus
WINEPREFIX=$WINEPREFIX winetricks -q vcrun2019
WINEPREFIX=$WINEPREFIX winetricks -q dotnet48
WINEPREFIX=$WINEPREFIX winetricks -q d3dx9 dxvk

# Set back environment to Windows 10
echo "[5/9] Set back environment to Windows 10..."
WINEPREFIX=$WINEPREFIX winecfg -v=win10

# WebView2
echo "[6/9] Installing WebView2 Runtime..."
wget -q -O webview2.exe "$URL_WEBVIEW"
WINEPREFIX=$WINEPREFIX wine webview2.exe /silent /install || true
rm -f webview2.exe

# MetaTrader 5
echo "[7/9] Downloading MetaTrader 5..."
wget -q -O mt5setup.exe "$URL_MT5"

echo "[8/9] Installing MetaTrader 5..."
WINEPREFIX=$WINEPREFIX wine mt5setup.exe || true

# Summary
WINEPREFIX=$WINEPREFIX winetricks list-installed 

# Clean up
echo "[9/9] Cleaning..."
rm -f /tmp/wine-gecko.msi mt5setup.exe
WINEPREFIX=$WINEPREFIX wineserver -k || true
WINEPREFIX=$WINEPREFIX wineboot -r >/dev/null 2>&1 || true

echo "=========================================="
echo "Installation complete!"
echo "Run MetaTrader 5 using:"
echo "   WINEPREFIX=$WINEPREFIX wine \"$WINEPREFIX/drive_c/Program Files/MetaTrader 5/terminal64.exe\""
echo
echo "Environment summary:"
echo " - Wine mode   : 64-bit"
echo " - Windows mode: Windows 10"
echo " - Installed   : Gecko $GECKO_VERSION"
echo "                 Corefonts, GDI+, MSXML3/6"
echo "                 VCRun2019, DotNet48, WebView2"
echo "                 DirectX 9, DXVK"
echo " - Market tab ready immediately."
echo "=========================================="
