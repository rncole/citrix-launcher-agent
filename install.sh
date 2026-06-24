#!/bin/zsh

set -euo pipefail

LABEL="com.example.citrix-ica-launcher"
USER_NAME="$(whoami)"
HOME_DIR="$HOME"
SCRIPT_SRC="./launch-citrix-ica.sh"
PLIST_DEST="$HOME_DIR/Library/LaunchAgents/$LABEL.plist"
SCRIPT_DEST="$HOME_DIR/bin/launch-citrix-ica.sh"

if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "ERROR: Run this installer from the folder containing launch-citrix-ica.sh"
  exit 1
fi

mkdir -p "$HOME_DIR/bin"
mkdir -p "$HOME_DIR/Library/LaunchAgents"

cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

cat > "$PLIST_DEST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
      <string>$SCRIPT_DEST</string>
    </array>

    <key>WatchPaths</key>
    <array>
      <string>$HOME_DIR/Downloads</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$HOME_DIR/Library/Logs/citrix-ica-launcher.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$HOME_DIR/Library/Logs/citrix-ica-launcher.stderr.log</string>
  </dict>
</plist>
EOF

plutil -lint "$PLIST_DEST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"
launchctl enable "gui/$(id -u)/$LABEL"

echo "Installed and loaded $LABEL"
echo "IMPORTANT: Grant Full Disk Access to /bin/zsh in System Settings > Privacy & Security > Full Disk Access."
echo "Then test by downloading a new .ica file."
echo "Log: $HOME_DIR/Library/Logs/citrix-ica-launcher.log"
