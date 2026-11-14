#!/bin/bash
# Build and install BlenderQuickLook.app (ad-hoc signed, local use).
set -euo pipefail
cd "$(dirname "$0")"
APP=build/BlenderQuickLook.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/PlugIns/BlenderPreview.appex/Contents/MacOS
cp Host/Info.plist $APP/Contents/Info.plist
cp Preview/Info.plist $APP/Contents/PlugIns/BlenderPreview.appex/Contents/Info.plist
swiftc -O -parse-as-library -module-name BlenderPreview -application-extension \
  -Xlinker -e -Xlinker _NSExtensionMain -framework Quartz -framework SceneKit -framework Cocoa \
  Preview/PreviewViewController.swift -o $APP/Contents/PlugIns/BlenderPreview.appex/Contents/MacOS/BlenderPreview
swiftc -O Host/main.swift -o $APP/Contents/MacOS/BlenderQuickLook
swiftc -O Helper/main.swift -o build/blender-ql-helper
codesign -f -s - --entitlements Preview/Preview.entitlements $APP/Contents/PlugIns/BlenderPreview.appex
codesign -f -s - $APP
if [ "${1:-}" = install ]; then
  rm -rf ~/Applications/BlenderQuickLook.app; mkdir -p ~/Applications
  cp -R $APP ~/Applications/
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/BlenderQuickLook.app
  pluginkit -a ~/Applications/BlenderQuickLook.app/Contents/PlugIns/BlenderPreview.appex
  pluginkit -e use -i org.vsekai.BlenderQuickLook.Preview
  HD=~/Library/Application\ Support/BlenderQuickLook; mkdir -p "$HD"
  rm -rf "$HD/pixi-env"; mkdir -p "$HD/pixi-env"
  cp pixi-env/pixi.toml pixi-env/pixi.lock pixi-env/convert.py "$HD/pixi-env/"
  (cd "$HD/pixi-env" && pixi install --locked)
  cp build/blender-ql-helper "$HD/blender-ql-helper"; codesign -f -s - "$HD/blender-ql-helper"
  PL=~/Library/LaunchAgents/org.vsekai.BlenderQuickLook.Helper.plist
  cat > $PL <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>org.vsekai.BlenderQuickLook.Helper</string>
<key>ProgramArguments</key><array><string>$HD/blender-ql-helper</string></array>
<key>MachServices</key><dict><key>org.vsekai.BlenderQuickLook.Helper</key><true/></dict>
</dict></plist>
EOF
  launchctl bootout gui/$(id -u) $PL 2>/dev/null || true
  launchctl bootstrap gui/$(id -u) $PL
  qlmanage -r; qlmanage -r cache
fi
