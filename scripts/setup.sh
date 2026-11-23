#!/usr/bin/env bash
# Install the iOS-over-USB toolchain (libimobiledevice + ideviceinstaller).
# Optional: mitmproxy for dynamic traffic analysis.
set -euo pipefail

echo "== iOS USB Security Audit: toolchain setup =="

OS="$(uname -s)"

install_mac() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install it first:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  fi
  eval "$(brew shellenv)" 2>/dev/null || true
  brew install libimobiledevice ideviceinstaller
  echo
  read -r -p "Also install mitmproxy for traffic analysis? [y/N] " a
  [[ "${a:-N}" =~ ^[Yy]$ ]] && brew install mitmproxy || true
}

install_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y libimobiledevice-utils ideviceinstaller usbmuxd
    read -r -p "Also install mitmproxy? [y/N] " a
    [[ "${a:-N}" =~ ^[Yy]$ ]] && sudo apt-get install -y mitmproxy || true
  else
    echo "Non-apt Linux: install 'libimobiledevice', 'ideviceinstaller' and 'usbmuxd'"
    echo "with your package manager (dnf/pacman/zypper)."
    exit 1
  fi
}

case "$OS" in
  Darwin) install_mac ;;
  Linux)  install_linux ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

echo
echo "== Verifying =="
for t in idevice_id ideviceinfo ideviceinstaller idevicecrashreport afcclient; do
  if command -v "$t" >/dev/null 2>&1; then echo "  ok  $t"; else echo "  MISSING  $t"; fi
done
echo
echo "Done. Connect the device, unlock it, tap 'Trust', then run: bash scripts/audit.sh"
