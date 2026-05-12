import Foundation

public final class UsageCacheStore {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DeepSeekUsageMonitor", isDirectory: true)
        cacheDirectory = appDir.appendingPathComponent("cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(usage: UsageAmountReport, month: Int, year: Int) {
        let url = cacheDirectory.appendingPathComponent("usage_\(year)_\(month).json")
        do {
            let data = try encoder.encode(usage)
            try data.write(to: url)
        } catch {
            // Cache write failures are non-critical
        }
    }

    public func save(cost: UsageCostReport, month: Int, year: Int) {
        let url = cacheDirectory.appendingPathComponent("cost_\(year)_\(month).json")
        do {
            let data = try encoder.encode(cost)
            try data.write(to: url)
        } catch {
            // Cache write failures are non-critical
        }
    }

    public func loadUsage(month: Int, year: Int) -> UsageAmountReport? {
        let url = cacheDirectory.appendingPathComponent("usage_\(year)_\(month).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(UsageAmountReport.self, from: data)
        } catch {
            return nil
        }
    }

    public func loadCost(month: Int, year: Int) -> UsageCostReport? {
        let url = cacheDirectory.appendingPathComponent("cost_\(year)_\(month).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(UsageCostReport.self, from: data)
        } catch {
            return nil
        }
    }

    public func isCacheValid(month: Int, year: Int, maxAge: TimeInterval = 3600) -> Bool {
        let url = cacheDirectory.appendingPathComponent("usage_\(year)_\(month).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modificationDate) < maxAge
    }

    public func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
