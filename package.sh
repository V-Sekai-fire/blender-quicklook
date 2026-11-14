#!/bin/bash
# Build and zip a prebuilt release into build/BlenderQuickLook.zip.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
rm -rf build/pkg && mkdir -p build/pkg/pixi-env
cp -R build/BlenderQuickLook.app build/pkg/
cp build/blender-ql-helper install.sh build/pkg/
cp pixi-env/pixi.toml pixi-env/pixi.lock pixi-env/convert.py build/pkg/pixi-env/
(cd build/pkg && zip -qry ../BlenderQuickLook.zip .)
echo build/BlenderQuickLook.zip
