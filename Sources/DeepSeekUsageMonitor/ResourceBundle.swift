import Foundation

/// Custom resource bundle loader that correctly searches Contents/Resources/
/// instead of the .app root (which is what SPM's default Bundle.module does).
///
/// Usage: Instead of `Bundle.module.url(...)`, use `ResourceBundle.url(...)`
enum ResourceBundle {
    /// The resource bundle containing platform logos and other assets
    static let bundle: Bundle = {
        let bundleName = "DeepSeekUsageMonitor_DeepSeekUsageMonitor"

        let searchPaths: [String] = [
            // Standard macOS app structure: Contents/Resources/
            Bundle.main.bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(bundleName).bundle").path,
            // Fallback: .app root (for backwards compatibility)
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle").path,
            // Development build path (GitHub Actions runner)
            "/Users/runner/work/DeepSeekUsageMonitor/DeepSeekUsageMonitor/.build/arm64-apple-macosx/release/\(bundleName).bundle",
            // Local development path
            FileManager.default.currentDirectoryPath + "/.build/release/\(bundleName).bundle",
        ]

        for path in searchPaths {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        fatalError("Could not load resource bundle. Searched paths:\n\(searchPaths.joined(separator: "\n"))")
    }()

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        bundle.url(forResource: name, withExtension: ext)
    }
}
