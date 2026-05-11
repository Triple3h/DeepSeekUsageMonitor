import Foundation

enum LaunchAtLoginManager {
    private static let label = "com.deepseekusagemonitor.launch"
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    @discardableResult
    static func enable() -> Bool {
        let executablePath = Bundle.main.executablePath ?? Bundle.main.bundlePath

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        do {
            let directory = plistURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", plistURL.path]
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @discardableResult
    static func disable() -> Bool {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return true }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", plistURL.path]
            try process.run()
            process.waitUntilExit()

            try FileManager.default.removeItem(at: plistURL)
            return true
        } catch {
            return false
        }
    }
}
