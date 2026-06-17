import Foundation

public final class UsageCacheStore {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DeepSeekUsageMonitor", isDirectory: true)
        cacheDirectory = appDir.appendingPathComponent("cache", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            #if DEBUG
            print("⚠️ Cache directory creation failed: \(error)")
            #endif
        }
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // 迁移旧缓存文件（首次启动时）
        migrateOldCacheFiles()
    }

    // MARK: - Generic Cache API

    /// 保存可缓存报告
    public func save<T: CacheableReport>(_ report: T, year: Int, month: Int) {
        ensurePlatformDirectoryExists(T.platformIdentifier)
        let url = cacheFileURL(for: T.self, year: year, month: month)
        do {
            let data = try encoder.encode(report)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("⚠️ Cache write failed: \(error)")
            #endif
        }
    }

    /// 加载可缓存报告
    public func load<T: CacheableReport>(_ type: T.Type, year: Int, month: Int) -> T? {
        let url = cacheFileURL(for: type, year: year, month: month)
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    /// 检查缓存是否有效（未过期）
    public func isValid<T: CacheableReport>(
        _ type: T.Type,
        year: Int,
        month: Int,
        maxAge: TimeInterval = 3600
    ) -> Bool {
        let url = cacheFileURL(for: type, year: year, month: month)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modificationDate) < maxAge
    }

    /// 加载缓存（仅在有效时返回）
    public func loadIfValid<T: CacheableReport>(
        _ type: T.Type,
        year: Int,
        month: Int,
        maxAge: TimeInterval = 3600
    ) -> T? {
        guard isValid(type, year: year, month: month, maxAge: maxAge) else { return nil }
        return load(type, year: year, month: month)
    }

    /// 清除指定平台的所有缓存
    public func clearPlatform(_ platform: String) {
        let platformDir = cacheDirectory.appendingPathComponent(platform, isDirectory: true)
        try? FileManager.default.removeItem(at: platformDir)
    }

    /// 清除所有缓存
    public func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func cacheFileURL<T: CacheableReport>(for type: T.Type, year: Int, month: Int) -> URL {
        let platformDir = cacheDirectory.appendingPathComponent(T.platformIdentifier, isDirectory: true)
        let fileName = "\(T.dataTypeIdentifier)_\(year)_\(String(format: "%02d", month)).json"
        return platformDir.appendingPathComponent(fileName)
    }

    private func ensurePlatformDirectoryExists(_ platform: String) {
        let platformDir = cacheDirectory.appendingPathComponent(platform, isDirectory: true)
        try? FileManager.default.createDirectory(at: platformDir, withIntermediateDirectories: true)
    }

    // MARK: - Migration

    /// 迁移旧缓存文件到新目录结构
    private func migrateOldCacheFiles() {
        let deepseekDir = cacheDirectory.appendingPathComponent("deepseek", isDirectory: true)

        // 确保目标目录存在（只创建一次）
        try? FileManager.default.createDirectory(at: deepseekDir, withIntermediateDirectories: true)

        // 旧文件名模式: usage_{year}_{month}.json, cost_{year}_{month}.json
        let prefixes = ["usage", "cost"]

        for prefix in prefixes {
            // 查找匹配的旧文件
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else {
                continue
            }

            for fileName in files where fileName.hasPrefix(prefix + "_") && fileName.hasSuffix(".json") {
                let oldURL = cacheDirectory.appendingPathComponent(fileName)
                let newURL = deepseekDir.appendingPathComponent(fileName)

                // 移动文件
                try? FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        }
    }
}
