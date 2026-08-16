#!/usr/bin/env bash
# setup.sh - Automated dependency installer for krsnvim (Linux / WSL / Git Bash)
# Idempotent: Safe to run multiple times, only installs missing packages.

set -e

echo -e "\033[1;36m🦊 Checking dependencies for krsnvim...\033[0m"

# Required CLI tools for krsnvim (excluding Mason / internal Neovim plugins)
# Format: "command:package_name:alternative_command"
COMMANDS=(
  "nvim:neovim"
  "git:git"
  "rg:ripgrep"
  "fd:fd-find:fdfind"
  "chafa:chafa"
  "gcc:gcc"
  "node:nodejs-lts:nodejs"
  "bun:bun"
  "go:golang:go"
  "dotnet:dotnet-sdk:dotnet"
)

MISSING_CMDS=()
MISSING_PKGS=()

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# 1. Check existing installations
for entry in "${COMMANDS[@]}"; do
  IFS=":" read -r cmd pkg alt_cmd <<< "$entry"
  if check_cmd "$cmd" || ([ -n "$alt_cmd" ] && check_cmd "$alt_cmd"); then
    echo -e "  - \033[0;90m$pkg ($cmd): Already installed\033[0m"
  else
    echo -e "  - \033[1;33m$pkg ($cmd): Missing\033[0m"
    MISSING_CMDS+=("$cmd")
    MISSING_PKGS+=("$pkg")
  fi
done

# 2. If nothing missing, report synced and exit
if [ ${#MISSING_CMDS[@]} -eq 0 ]; then
  echo -e "\n\033[1;32m[+] Nothing to install: all dependencies are synced!\033[0m"
  exit 0
fi

echo -e "\n\033[1;33m[*] Missing dependencies detected: ${MISSING_CMDS[*]}\033[0m"

# 3. Handle Windows Git Bash / MSYS environment
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
  echo "[*] Windows environment detected. Delegating to PowerShell setup..."
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -ExecutionPolicy Bypass -File "./setup.ps1"
  elif command -v scoop >/dev/null 2>&1; then
    scoop bucket add main 2>/dev/null || true
    scoop bucket add extras 2>/dev/null || true
    for pkg in "${MISSING_PKGS[@]}"; do
      case "$pkg" in
        fd-find) pkg="fd" ;;
        golang) pkg="go" ;;
      esac
      scoop install "$pkg" || true
    done
  else
    echo "[!] PowerShell or Scoop not found in PATH."
    exit 1
  fi
  exit 0
fi

# 4. Install Bun via official script if missing on Linux/macOS
if ! check_cmd bun; then
  echo "[*] Installing Bun runtime..."
  curl -fsSL https://bun.sh/install | bash || true
fi

# 5. Linux / WSL package managers
if command -v apt-get >/dev/null 2>&1; then
  echo "[*] Debian/Ubuntu/WSL detected. Running apt install..."
  sudo apt-get update
  sudo apt-get install -y neovim git ripgrep fd-find chafa build-essential nodejs golang-go dotnet-sdk-8.0 || true
elif command -v dnf >/dev/null 2>&1; then
  echo "[*] Fedora detected. Running dnf install..."
  sudo dnf install -y neovim git ripgrep fd-find chafa gcc nodejs golang dotnet-sdk-8.0 || true
elif command -v pacman >/dev/null 2>&1; then
  echo "[*] Arch Linux detected. Running pacman install..."
  sudo pacman -Sy --needed neovim git ripgrep fd chafa gcc nodejs go dotnet-sdk || true
elif command -v brew >/dev/null 2>&1; then
  echo "[*] macOS detected. Running brew install..."
  brew install neovim git ripgrep fd chafa gcc node bun go dotnet || true
else
  echo -e "\033[1;31m[!] Package manager not detected. Please install missing tools manually: ${MISSING_CMDS[*]}\033[0m"
  exit 1
fi

echo -e "\n\033[1;32m[+] Setup complete! All dependencies are synced.\033[0m"
