import Foundation
import CryptoKit

// Unsandboxed LaunchAgent: converts .blend bytes to USDZ with the bpy wheel (pixi env).
// The sandboxed Quick Look extension cannot fork, so it asks us over XPC.
// Results are cached by SHA-256 of the .blend bytes.
let serviceName = "org.vsekai.BlenderQuickLook.Helper"

@objc protocol BlendConverting {
    func convert(blend: Data, reply: @escaping (Data?, String?) -> Void)
}

let home = FileManager.default.homeDirectoryForCurrentUser
let support = home.appendingPathComponent("Library/Application Support/BlenderQuickLook")
let python = support.appendingPathComponent("pixi-env/.pixi/envs/default/bin/python")
let script = support.appendingPathComponent("pixi-env/convert.py")
let cacheDir = home.appendingPathComponent("Library/Caches/BlenderQuickLook")

final class Converter: NSObject, BlendConverting, NSXPCListenerDelegate {
    func listener(_ l: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
        c.exportedInterface = NSXPCInterface(with: BlendConverting.self)
        c.exportedObject = self
        c.resume()
        return true
    }

    func convert(blend: Data, reply: @escaping (Data?, String?) -> Void) {
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            return reply(nil, "bpy environment missing; run build.sh install")
        }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let key = SHA256.hash(data: blend).map { String(format: "%02x", $0) }.joined()
        let cached = cacheDir.appendingPathComponent(key + ".usdz")
        if let hit = try? Data(contentsOf: cached) { return reply(hit, nil) }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("blenderql-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let src = work.appendingPathComponent("in.blend"), out = work.appendingPathComponent("scene.usdz")
            try blend.write(to: src)
            let p = Process()
            p.executableURL = python
            p.arguments = [script.path, src.path, out.path]
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
            try p.run()
            let log = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard let data = try? Data(contentsOf: out) else {
                return reply(nil, "bpy produced no USD: " + String(decoding: log.suffix(400), as: UTF8.self))
            }
            try? data.write(to: cached)
            reply(data, nil)
        } catch { reply(nil, "\(error)") }
    }
}

let converter = Converter()
let listener = NSXPCListener(machServiceName: serviceName)
listener.delegate = converter
listener.resume()
RunLoop.main.run()
