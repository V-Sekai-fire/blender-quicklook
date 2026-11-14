import Cocoa
import Quartz
import SceneKit

/// Quick Look preview for .blend files.
/// Runs Blender headless to export the scene to USD, then shows it in an
/// interactive SceneKit view (orbit / pan / zoom). No embedded thumbnail is used.
final class PreviewViewController: NSViewController, QLPreviewingController {
    private let scnView = SCNView()
    private let status = NSTextField(labelWithString: "")

    override func loadView() {
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        scnView.autoresizingMask = [.width, .height]
        status.alignment = .center
        status.textColor = .white
        status.frame = NSRect(x: 0, y: 8, width: 800, height: 20)
        status.autoresizingMask = [.width]
        scnView.addSubview(status)
        view = scnView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let blend = try Data(contentsOf: url)
        let conn = NSXPCConnection(machServiceName: "org.vsekai.BlenderQuickLook.Helper")
        conn.remoteObjectInterface = NSXPCInterface(with: BlendConverting.self)
        conn.resume()
        defer { conn.invalidate() }
        let usdz: Data = try await withCheckedThrowingContinuation { c in
            let proxy = conn.remoteObjectProxyWithErrorHandler { c.resume(throwing: $0) } as! BlendConverting
            proxy.convert(blend: blend) { data, err in
                if let data { c.resume(returning: data) }
                else { c.resume(throwing: NSError(domain: "BlenderQuickLook", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: err ?? "conversion failed"])) }
            }
        }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appendingPathComponent("scene.usdz")
        try usdz.write(to: file)
        let scene = try SCNScene(url: file, options: nil)
        await MainActor.run { self.show(scene, name: url.lastPathComponent) }
    }

    /// Fix up what the USD import gives SceneKit for MToon-style avatars.
    /// - Blender's MToon "compatible shader" exports metallic = 1, which renders
    ///   everything as dark metal under PBR; force metalness to 0.
    /// - Blender writes no normals for meshes with shape keys (the face). Lit
    ///   shading on such a mesh hides the eyes, brows and mouth, so draw those unlit.
    private func fixMaterials(_ scene: SCNScene) {
        scene.rootNode.enumerateHierarchy { node, _ in
            guard let g = node.geometry else { return }
            let noNormals = g.sources(for: .normal).isEmpty
            for m in g.materials {
                m.metalness.contents = 0.0
                m.roughness.contents = 1.0
                if noNormals { m.lightingModel = .constant }
            }
        }
    }

    @MainActor private func show(_ scene: SCNScene, name: String) {
        fixMaterials(scene)
        // Frame the content with our own camera.
        let (mn, mx) = scene.rootNode.boundingBox
        let center = SCNVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        let size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera!.zNear = Double(size) / 1000
        cam.camera!.zFar = Double(size) * 100
        let d = size * 1.8
        cam.position = SCNVector3(center.x + d * 0.6, center.y + d * 0.5, center.z + d)
        cam.look(at: center)
        scene.rootNode.addChildNode(cam)
        scnView.scene = scene
        scnView.pointOfView = cam
        status.stringValue = name
    }
}

@objc protocol BlendConverting {
    func convert(blend: Data, reply: @escaping (Data?, String?) -> Void)
}
