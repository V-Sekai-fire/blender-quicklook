#!/bin/bash
# Install a prebuilt BlenderQuickLook release (run from the unzipped folder).
# Needs pixi (https://pixi.sh). Installs the app, the bpy environment and the LaunchAgent.
set -euo pipefail
cd "$(dirname "$0")"
command -v pixi >/dev/null || { echo "pixi not found: install it from https://pixi.sh" >&2; exit 1; }
HD="$HOME/Library/Application Support/BlenderQuickLook"
rm -rf "$HOME/Applications/BlenderQuickLook.app"; mkdir -p "$HOME/Applications" "$HD"
cp -R BlenderQuickLook.app "$HOME/Applications/"
rm -rf "$HD/pixi-env"; mkdir -p "$HD/pixi-env"
cp pixi-env/pixi.toml pixi-env/pixi.lock pixi-env/convert.py "$HD/pixi-env/"
(cd "$HD/pixi-env" && pixi install --locked)
cp blender-ql-helper "$HD/blender-ql-helper"; codesign -f -s - "$HD/blender-ql-helper"
PL="$HOME/Library/LaunchAgents/org.vsekai.BlenderQuickLook.Helper.plist"
cat > "$PL" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>org.vsekai.BlenderQuickLook.Helper</string>
<key>ProgramArguments</key><array><string>$HD/blender-ql-helper</string></array>
<key>MachServices</key><dict><key>org.vsekai.BlenderQuickLook.Helper</key><true/></dict>
</dict></plist>
EOF
launchctl bootout "gui/$(id -u)" "$PL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PL"
xattr -dr com.apple.quarantine "$HOME/Applications/BlenderQuickLook.app" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Applications/BlenderQuickLook.app"
pluginkit -a "$HOME/Applications/BlenderQuickLook.app/Contents/PlugIns/BlenderPreview.appex"
pluginkit -e use -i org.vsekai.BlenderQuickLook.Preview
qlmanage -r; qlmanage -r cache
echo "Installed. Select a .blend in Finder and press Space."
