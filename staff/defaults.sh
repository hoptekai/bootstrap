#!/usr/bin/env bash
# Minimal macOS security baseline for the STAFF profile (no Nix, so no nix-darwin).
# Idempotent — safe to re-run. Mirrors the important bits of modules/macos-defaults.nix.
set -euo pipefail

echo "==> Applying staff macOS security baseline"

# Application firewall on, stealth mode.
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on >/dev/null

# Require password immediately after sleep / screensaver.
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Show all file extensions.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllExtensions -bool true

# Screenshots into ~/Screenshots.
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location "$HOME/Screenshots"

# Apply UI changes.
killall Finder SystemUIServer 2>/dev/null || true

echo "==> Done."
