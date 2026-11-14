import Cocoa
// Host app exists only to carry the Quick Look extension and the .blend type declaration.
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let alert = NSAlert()
alert.messageText = "Blender Quick Look is installed"
alert.informativeText = "Select a .blend file in Finder and press Space. Uses the bpy Python wheel (no Blender.app needed)."
alert.runModal()
