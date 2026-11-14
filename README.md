# Blender QuickLook

macOS Quick Look preview for `.blend` files. Press Space on a `.blend` in Finder and get the real scene in an interactive 3D view (orbit, pan, zoom), shape keys included. It does not use the thumbnail embedded in the file.

Related: [model-quicklook](https://github.com/V-Sekai-fire/model-quicklook) does the same for `.vrm`, `.glb` and `.gltf`.

## How it works

1. The sandboxed Quick Look extension (`Preview/`) sends the `.blend` bytes over XPC to a LaunchAgent, because a sandboxed extension cannot spawn processes.
2. The helper (`Helper/`) runs `pixi-env/convert.py` with the [`bpy`](https://pypi.org/project/bpy/) wheel from a pixi environment. Blender.app is not needed. The result is USDZ.
3. The extension shows the USDZ in a SceneKit view.
4. The helper caches each USDZ in `~/Library/Caches/BlenderQuickLook/`, keyed by the SHA-256 of the file, so repeat previews are instant.

## Install

Requires macOS 13+, Xcode command line tools and [pixi](https://pixi.sh).

    ./build.sh install

This builds an ad-hoc signed app into `~/Applications`, installs the pixi environment into `~/Library/Application Support/BlenderQuickLook`, and loads the LaunchAgent. If previews do not appear, approve the background item in System Settings, Login Items.

## What it does not have

- Thumbnails in Finder. Only the Space preview exists.
- Notarization. The build is ad-hoc signed, for local use.
- Testing beyond simple scenes. Armatures, textures and large files are untried.
- Correct camera framing for every scene. The initial view can be off-centre.

## Licence

MIT. See [LICENSE](LICENSE).
