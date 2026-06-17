import Foundation

public struct UsageSummary: Equatable {
    public var sourceName: String = "未导入"
    public var rows: Int = 0
    public var promptTokens: Int = 0
    public var completionTokens: Int = 0
    public var totalTokens: Int = 0
    public var amount: Decimal = 0
    public var currency: String = ""
    public var groupedByKey: [String: KeyUsage] = [:]

    public init() {}

    public init(
        sourceName: String = "未导入",
        rows: Int = 0,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        totalTokens: Int = 0,
        amount: Decimal = 0,
        currency: String = "",
        groupedByKey: [String: KeyUsage] = [:]
    ) {
        self.sourceName = sourceName
        self.rows = rows
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.amount = amount
        self.currency = currency
        self.groupedByKey = groupedByKey
    }

    public var hasData: Bool {
        rows > 0
    }
}

public struct KeyUsage: Equatable, Identifiable {
    public let id: String
    public var rows: Int = 0
    public var promptTokens: Int = 0
    public var completionTokens: Int = 0
    public var totalTokens: Int = 0
    public var amount: Decimal = 0

    public init(id: String, rows: Int = 0, promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0, amount: Decimal = 0) {
        self.id = id
        self.rows = rows
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.amount = amount
    }
}

public struct TokenEstimate: Equatable {
    public let englishCharacters: Int
    public let chineseCharacters: Int
    public let otherCharacters: Int

    public init(englishCharacters: Int, chineseCharacters: Int, otherCharacters: Int) {
        self.englishCharacters = englishCharacters
        self.chineseCharacters = chineseCharacters
        self.otherCharacters = otherCharacters
    }

    public var estimatedTokens: Int {
        let english = Double(englishCharacters) * 0.3
        let chinese = Double(chineseCharacters) * 0.6
        let other = Double(otherCharacters) * 0.5
        return Int((english + chinese + other).rounded(.up))
    }
}

public struct PlatformCredentialStatus: Equatable {
    public let hasBearerToken: Bool

    public init(hasBearerToken: Bool) {
        self.hasBearerToken = hasBearerToken
    }
}

public struct PlatformSummary: Equatable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let metrics: [PlatformMetric]

    public init(endpoint: URL, capturedAt: Date, rawJSON: String, metrics: [PlatformMetric]) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.metrics = metrics
    }
}

public struct PlatformMetric: Equatable, Identifiable {
    public var id: String { path }

    public let path: String
    public let value: String

    public init(path: String, value: String) {
        self.path = path
        self.value = value
    }
}

public struct UsageAmountReport: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let models: [UsageModelAmount]
    public let days: [UsageDayAmount]

    public init(endpoint: URL, capturedAt: Date, rawJSON: String, models: [UsageModelAmount], days: [UsageDayAmount]) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.models = models
        self.days = days
    }

    public var requestCount: Int {
        models.reduce(0) { $0 + $1.requestCount }
    }

    public var promptCacheHitTokens: Int {
        models.reduce(0) { $0 + $1.promptCacheHitTokens }
    }

    public var promptCacheMissTokens: Int {
        models.reduce(0) { $0 + $1.promptCacheMissTokens }
    }

    public var responseTokens: Int {
        models.reduce(0) { $0 + $1.responseTokens }
    }

    public var inputTokens: Int {
        models.reduce(0) { $0 + $1.inputTokens }
    }

    public var totalTokens: Int {
        inputTokens + responseTokens
    }
}

public struct UsageModelAmount: Equatable, Identifiable, Codable {
    public var id: String { model }

    public let model: String
    public let usage: [String: Int]

    public init(model: String, usage: [String: Int]) {
        self.model = model
        self.usage = usage
    }

    public var promptTokens: Int { usage["PROMPT_TOKEN", default: 0] }
    public var promptCacheHitTokens: Int { usage["PROMPT_CACHE_HIT_TOKEN", default: 0] }
    public var promptCacheMissTokens: Int { usage["PROMPT_CACHE_MISS_TOKEN", default: 0] }
    public var responseTokens: Int { usage["RESPONSE_TOKEN", default: 0] }
    public var requestCount: Int { usage["REQUEST", default: 0] }
    public var inputTokens: Int { promptTokens + promptCacheHitTokens + promptCacheMissTokens }
    public var totalTokens: Int { inputTokens + responseTokens }
}

public struct UsageDayAmount: Equatable, Identifiable, Codable {
    public var id: String { date }

    public let date: String
    public let models: [UsageModelAmount]

    public init(date: String, models: [UsageModelAmount]) {
        self.date = date
        self.models = models
    }

    public var requestCount: Int {
        models.reduce(0) { $0 + $1.requestCount }
    }

    public var totalTokens: Int {
        models.reduce(0) { $0 + $1.totalTokens }
    }
}

public struct UsageCostReport: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let currency: String
    public let models: [UsageCostModelAmount]
    public let days: [UsageCostDayAmount]

    public init(endpoint: URL, capturedAt: Date, rawJSON: String, currency: String, models: [UsageCostModelAmount], days: [UsageCostDayAmount]) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.currency = currency
        self.models = models
        self.days = days
    }

    public var totalCost: Decimal {
        models.reduce(0) { $0 + $1.totalCost }
    }
}

public struct UsageCostModelAmount: Equatable, Identifiable, Codable {
    public var id: String { model }

    public let model: String
    public let usage: [String: Decimal]

    public init(model: String, usage: [String: Decimal]) {
        self.model = model
        self.usage = usage
    }

    public var promptCost: Decimal { usage["PROMPT_TOKEN", default: 0] }
    public var promptCacheHitCost: Decimal { usage["PROMPT_CACHE_HIT_TOKEN", default: 0] }
    public var promptCacheMissCost: Decimal { usage["PROMPT_CACHE_MISS_TOKEN", default: 0] }
    public var responseCost: Decimal { usage["RESPONSE_TOKEN", default: 0] }
    public var requestCost: Decimal { usage["REQUEST", default: 0] }
    public var totalCost: Decimal {
        promptCost + promptCacheHitCost + promptCacheMissCost + responseCost + requestCost
    }
}

public struct UsageCostDayAmount: Equatable, Identifiable, Codable {
    public var id: String { date }

    public let date: String
    public let models: [UsageCostModelAmount]

    public init(date: String, models: [UsageCostModelAmount]) {
        self.date = date
        self.models = models
    }

    public var totalCost: Decimal {
        models.reduce(0) { $0 + $1.totalCost }
    }
}

public struct UserSummaryReport: Equatable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let currentToken: Int
    public let monthlyUsage: Int
    public let totalUsage: Int
    public let normalWallets: [PlatformWallet]
    public let bonusWallets: [PlatformWallet]
    public let monthlyCosts: [PlatformCost]
    public let totalAvailableTokenEstimation: Int

    public init(
        endpoint: URL,
        capturedAt: Date,
        rawJSON: String,
        currentToken: Int,
        monthlyUsage: Int,
        totalUsage: Int,
        normalWallets: [PlatformWallet],
        bonusWallets: [PlatformWallet],
        monthlyCosts: [PlatformCost],
        totalAvailableTokenEstimation: Int
    ) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.currentToken = currentToken
        self.monthlyUsage = monthlyUsage
        self.totalUsage = totalUsage
        self.normalWallets = normalWallets
        self.bonusWallets = bonusWallets
        self.monthlyCosts = monthlyCosts
        self.totalAvailableTokenEstimation = totalAvailableTokenEstimation
    }

    public var primaryCurrency: String {
        normalWallets.first?.currency ?? bonusWallets.first?.currency ?? monthlyCosts.first?.currency ?? "CNY"
    }

    public var normalBalance: Decimal {
        normalWallets.reduce(0) { $0 + $1.balanceDecimal }
    }

    public var bonusBalance: Decimal {
        bonusWallets.reduce(0) { $0 + $1.balanceDecimal }
    }

    public var totalBalance: Decimal {
        normalBalance + bonusBalance
    }

    public var monthlyCost: Decimal {
        monthlyCosts.reduce(0) { $0 + $1.amountDecimal }
    }
}

public struct PlatformWallet: Equatable, Identifiable {
    public var id: String { currency }

    public let currency: String
    public let balance: String
    public let tokenEstimation: String

    public init(currency: String, balance: String, tokenEstimation: String) {
        self.currency = currency
        self.balance = balance
        self.tokenEstimation = tokenEstimation
    }

    public var balanceDecimal: Decimal {
        Decimal(string: balance) ?? 0
    }

    public var tokenEstimationInt: Int {
        Int(tokenEstimation) ?? 0
    }
}

public struct PlatformCost: Equatable, Identifiable {
    public var id: String { currency }

    public let currency: String
    public let amount: String

    public init(currency: String, amount: String) {
        self.currency = currency
        self.amount = amount
    }

    public var amountDecimal: Decimal {
        Decimal(string: amount) ?? 0
    }
}

// MARK: - Mimo Platform Models

/// Mimo Cookie 解析结果
public struct MimoCookie: Equatable {
    public let serviceToken: String
    public let apiPlatformServiceToken: String?
    public let userId: String?
    public let apiPlatformPh: String?
    public let apiPlatformSlh: String?
    public let xiaomichatbotPh: String?
    public let rawCookie: String

    public init(
        serviceToken: String,
        apiPlatformServiceToken: String? = nil,
        userId: String? = nil,
        apiPlatformPh: String? = nil,
        apiPlatformSlh: String? = nil,
        xiaomichatbotPh: String? = nil,
        rawCookie: String
    ) {
        self.serviceToken = serviceToken
        self.apiPlatformServiceToken = apiPlatformServiceToken
        self.userId = userId
        self.apiPlatformPh = apiPlatformPh
        self.apiPlatformSlh = apiPlatformSlh
        self.xiaomichatbotPh = xiaomichatbotPh
        self.rawCookie = rawCookie
    }

    /// 生成完整的 Cookie Header
    public var cookieHeader: String {
        var parts: [String] = []

        if !serviceToken.isEmpty {
            parts.append("serviceToken=\(serviceToken)")
        }

        if let apiPlatformServiceToken, !apiPlatformServiceToken.isEmpty {
            parts.append("api-platform_serviceToken=\(apiPlatformServiceToken)")
        }

        if let userId, !userId.isEmpty {
            parts.append("userId=\(userId)")
        }

        if let apiPlatformPh, !apiPlatformPh.isEmpty {
            parts.append("api-platform_ph=\(apiPlatformPh)")
        }

        if let apiPlatformSlh, !apiPlatformSlh.isEmpty {
            parts.append("api-platform_slh=\(apiPlatformSlh)")
        }

        if let xiaomichatbotPh, !xiaomichatbotPh.isEmpty {
            parts.append("xiaomichatbot_ph=\(xiaomichatbotPh)")
        }

        return parts.joined(separator: "; ")
    }

    /// 解析 cookie 字符串
    public static func parse(_ cookieString: String) -> MimoCookie? {
        let trimmed = cookieString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var serviceToken = ""
        var apiPlatformServiceToken: String? = nil
        var userId: String? = nil
        var apiPlatformPh: String? = nil
        var apiPlatformSlh: String? = nil
        var xiaomichatbotPh: String? = nil

        // 解析 cookie 字段
        let pairs = trimmed.split(separator: ";")
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }

            let key = keyValue[0].trimmingCharacters(in: .whitespaces)
            let rawValue = keyValue[1].trimmingCharacters(in: .whitespaces)
            // 去掉 cookie 值两端的引号（浏览器 cookie 常见格式）
            let value: String
            if rawValue.count >= 2, rawValue.first == "\"", rawValue.last == "\"" {
                value = String(rawValue.dropFirst().dropLast())
            } else {
                value = rawValue
            }

            switch key {
            case "serviceToken":
                serviceToken = value
            case "api-platform_serviceToken":
                apiPlatformServiceToken = value
            case "userId":
                userId = value
            case "api-platform_ph":
                apiPlatformPh = value
            case "api-platform_slh":
                apiPlatformSlh = value
            case "xiaomichatbot_ph":
                xiaomichatbotPh = value
            default:
                break
            }
        }

        #if DEBUG
        print("\n========== Mimo Cookie Parse ==========")
        print("📝 Input length: \(trimmed.count) chars")
        print("✅ serviceToken: \(serviceToken.isEmpty ? "❌ MISSING" : "✓ (\(serviceToken.count) chars)")")
        print("  - api-platform_serviceToken: \(apiPlatformServiceToken != nil ? "✓" : "❌")")
        print("  - userId: \(userId ?? "❌")")
        print("  - api-platform_ph: \(apiPlatformPh != nil ? "✓" : "❌")")
        print("  - api-platform_slh: \(apiPlatformSlh != nil ? "✓" : "❌")")
        print("  - xiaomichatbot_ph: \(xiaomichatbotPh != nil ? "✓" : "❌")")
        print("=========================================\n")
        #endif

        guard !serviceToken.isEmpty else { return nil }

        return MimoCookie(
            serviceToken: serviceToken,
            apiPlatformServiceToken: apiPlatformServiceToken,
            userId: userId,
            apiPlatformPh: apiPlatformPh,
            apiPlatformSlh: apiPlatformSlh,
            xiaomichatbotPh: xiaomichatbotPh,
            rawCookie: trimmed
        )
    }
}

/// 预警模式标签协议：所有支持独立预警开关的计费模式枚举需遵循
public protocol WarningLabelProvider: CaseIterable, Hashable, RawRepresentable where RawValue == String {
    var warningLabel: String { get }
}

/// DeepSeek 计费模式
public enum DeepSeekBillingMode: String, Codable, Equatable, CaseIterable, Hashable, WarningLabelProvider {
    case payAsYouGo = "按量收费"

    public var warningLabel: String {
        switch self {
        case .payAsYouGo: return "DeepSeek 余额预警"
        }
    }
}

/// Mimo 计费模式
public enum MimoBillingMode: String, Codable, Equatable, CaseIterable, Hashable, WarningLabelProvider {
    case payAsYouGo = "按量收费"
    case tokenPlan = "Token Plan"

    public var warningLabel: String {
        switch self {
        case .payAsYouGo: return "Mimo 按量收费预警"
        case .tokenPlan:   return "Mimo Token Plan 预警"
        }
    }
}

/// Mimo 使用情况概览 (GET /api/v1/usage)
public struct MimoUsageOverview: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let tokenUsage: MimoTokenUsage
    public let accountRateLimit: MimoAccountRateLimit
    public let costUsage: MimoCostUsage
    public let pluginUsage: MimoPluginUsage

    public init(
        endpoint: URL,
        capturedAt: Date,
        rawJSON: String,
        tokenUsage: MimoTokenUsage,
        accountRateLimit: MimoAccountRateLimit,
        costUsage: MimoCostUsage,
        pluginUsage: MimoPluginUsage
    ) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.tokenUsage = tokenUsage
        self.accountRateLimit = accountRateLimit
        self.costUsage = costUsage
        self.pluginUsage = pluginUsage
    }

    public var totalTokens: Int {
        tokenUsage.totalToken
    }

    public var totalCost: Decimal {
        Decimal(string: costUsage.totalCost) ?? 0
    }

    public var currentMonthCost: Decimal {
        Decimal(string: costUsage.currentMonthCost) ?? 0
    }
}

public struct MimoTokenUsage: Equatable, Codable {
    public let inputToken: Int
    public let outputToken: Int
    public let cacheToken: Int
    public let totalToken: Int
    public let inputAudioDuration: Int

    public init(inputToken: Int, outputToken: Int, cacheToken: Int, totalToken: Int, inputAudioDuration: Int) {
        self.inputToken = inputToken
        self.outputToken = outputToken
        self.cacheToken = cacheToken
        self.totalToken = totalToken
        self.inputAudioDuration = inputAudioDuration
    }
}

public struct MimoAccountRateLimit: Equatable, Codable {
    public let tpm: Int
    public let rpm: Int
    public let queryTpm: Int
    public let concurrency: Int

    public init(tpm: Int, rpm: Int, queryTpm: Int, concurrency: Int) {
        self.tpm = tpm
        self.rpm = rpm
        self.queryTpm = queryTpm
        self.concurrency = concurrency
    }
}

public struct MimoCostUsage: Equatable, Codable {
    public let totalCost: String
    public let currentMonthCost: String

    public init(totalCost: String, currentMonthCost: String) {
        self.totalCost = totalCost
        self.currentMonthCost = currentMonthCost
    }
}

public struct MimoPluginUsage: Equatable, Codable {
    public let totalRequestCount: String
    public let webSearchRequestCount: String

    public init(totalRequestCount: String, webSearchRequestCount: String) {
        self.totalRequestCount = totalRequestCount
        self.webSearchRequestCount = webSearchRequestCount
    }
}

/// Mimo 账户余额 (GET /api/v1/balance)
public struct MimoBalanceReport: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let currency: String
    /// 可用余额（含赠送与现金）
    public let balance: Decimal
    /// 赠送余额
    public let giftBalance: Decimal
    /// 现金余额
    public let cashBalance: Decimal
    /// 冻结余额
    public let frozenBalance: Decimal

    public init(
        endpoint: URL,
        capturedAt: Date,
        rawJSON: String,
        currency: String,
        balance: Decimal,
        giftBalance: Decimal,
        cashBalance: Decimal,
        frozenBalance: Decimal
    ) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.currency = currency
        self.balance = balance
        self.giftBalance = giftBalance
        self.cashBalance = cashBalance
        self.frozenBalance = frozenBalance
    }

    /// 实际可用余额 = 总余额 - 冻结
    public var availableBalance: Decimal {
        max(0, balance - frozenBalance)
    }

    /// 冻结占比（0~1），无冻结时为 0
    public var frozenRatio: Double {
        guard balance > 0 else { return 0 }
        return (frozenBalance as NSDecimalNumber).doubleValue / (balance as NSDecimalNumber).doubleValue
    }
}

/// Mimo 按量收费详情列表 (POST /api/v1/usage/detail/list)
public struct MimoUsageDetailReport: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let currency: String
    public let details: [MimoUsageDetail]

    public init(endpoint: URL, capturedAt: Date, rawJSON: String, currency: String, details: [MimoUsageDetail]) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.currency = currency
        self.details = details
    }

    public var totalCost: Decimal {
        details.reduce(0) { $0 + $1.consumedAmountDecimal }
    }

    public var totalTokens: Int {
        details.reduce(0) { $0 + $1.totalToken }
    }

    public var requestCount: Int {
        details.reduce(0) { $0 + $1.requestCount }
    }
}

public struct MimoUsageDetail: Equatable, Identifiable, Codable {
    public var id: String { "\(date)-\(model)-\(apiKey)" }

    public let date: String
    public let model: String
    public let apiKey: String
    public let currency: String
    public let consumedAmount: String
    public let inputHitAmount: String
    public let inputMissAmount: String
    public let outputAmount: String
    public let totalToken: Int
    public let inputHitToken: Int
    public let inputMissToken: Int
    public let outputToken: Int
    public let requestCount: Int
    public let inputAudioDuration: Int

    public init(
        date: String,
        model: String,
        apiKey: String,
        currency: String,
        consumedAmount: String,
        inputHitAmount: String,
        inputMissAmount: String,
        outputAmount: String,
        totalToken: Int,
        inputHitToken: Int,
        inputMissToken: Int,
        outputToken: Int,
        requestCount: Int,
        inputAudioDuration: Int
    ) {
        self.date = date
        self.model = model
        self.apiKey = apiKey
        self.currency = currency
        self.consumedAmount = consumedAmount
        self.inputHitAmount = inputHitAmount
        self.inputMissAmount = inputMissAmount
        self.outputAmount = outputAmount
        self.totalToken = totalToken
        self.inputHitToken = inputHitToken
        self.inputMissToken = inputMissToken
        self.outputToken = outputToken
        self.requestCount = requestCount
        self.inputAudioDuration = inputAudioDuration
    }

    public var consumedAmountDecimal: Decimal {
        Decimal(string: consumedAmount) ?? 0
    }

    public var inputTokens: Int {
        inputHitToken + inputMissToken
    }
}

/// Mimo Token Plan 使用情况 (GET /api/v1/tokenPlan/usage)
public struct MimoTokenPlanUsage: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let monthUsage: MimoTokenPlanMonthUsage
    public let usage: MimoTokenPlanTotalUsage

    public init(
        endpoint: URL,
        capturedAt: Date,
        rawJSON: String,
        monthUsage: MimoTokenPlanMonthUsage,
        usage: MimoTokenPlanTotalUsage
    ) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.monthUsage = monthUsage
        self.usage = usage
    }

    public var usedTokens: Int {
        usage.planTotalToken.used
    }

    public var limitTokens: Int {
        usage.planTotalToken.limit
    }

    public var remainingTokens: Int {
        limitTokens - usedTokens
    }

    public var usagePercent: Double {
        usage.planTotalToken.percent
    }
}

public struct MimoTokenPlanMonthUsage: Equatable, Codable {
    public let percent: Double
    public let items: [MimoTokenPlanUsageItem]

    public init(percent: Double, items: [MimoTokenPlanUsageItem]) {
        self.percent = percent
        self.items = items
    }
}

public struct MimoTokenPlanTotalUsage: Equatable, Codable {
    public let percent: Double
    public let planTotalToken: MimoTokenPlanUsageItem
    public let compensationTotalToken: MimoTokenPlanUsageItem

    public init(percent: Double, planTotalToken: MimoTokenPlanUsageItem, compensationTotalToken: MimoTokenPlanUsageItem) {
        self.percent = percent
        self.planTotalToken = planTotalToken
        self.compensationTotalToken = compensationTotalToken
    }
}

public struct MimoTokenPlanUsageItem: Equatable, Codable {
    public let name: String
    public let used: Int
    public let limit: Int
    public let percent: Double

    public init(name: String, used: Int, limit: Int, percent: Double) {
        self.name = name
        self.used = used
        self.limit = limit
        self.percent = percent
    }
}

/// Mimo Token Plan 详情列表 (POST /api/v1/usage/token-plan/list)
public struct MimoTokenPlanDetailReport: Equatable, Codable {
    public let endpoint: URL
    public let capturedAt: Date
    public let rawJSON: String
    public let details: [MimoTokenPlanDetail]

    public init(endpoint: URL, capturedAt: Date, rawJSON: String, details: [MimoTokenPlanDetail]) {
        self.endpoint = endpoint
        self.capturedAt = capturedAt
        self.rawJSON = rawJSON
        self.details = details
    }

    public var totalTokens: Int {
        details.reduce(0) { $0 + $1.totalToken }
    }

    public var requestCount: Int {
        details.reduce(0) { $0 + $1.requestCount }
    }
}

public struct MimoTokenPlanDetail: Equatable, Identifiable, Codable {
    public var id: String { "\(date)-\(model)" }

    public let date: String
    public let model: String
    public let totalToken: Int
    public let inputHitToken: Int
    public let inputMissToken: Int
    public let outputToken: Int
    public let requestCount: Int
    public let inputAudioDuration: Int

    public init(
        date: String,
        model: String,
        totalToken: Int,
        inputHitToken: Int,
        inputMissToken: Int,
        outputToken: Int,
        requestCount: Int,
        inputAudioDuration: Int
    ) {
        self.date = date
        self.model = model
        self.totalToken = totalToken
        self.inputHitToken = inputHitToken
        self.inputMissToken = inputMissToken
        self.outputToken = outputToken
        self.requestCount = requestCount
        self.inputAudioDuration = inputAudioDuration
    }

    public var inputTokens: Int {
        inputHitToken + inputMissToken
    }
}

// MARK: - Mimo → 统一用量/成本模型转换

/// 将 Mimo 按量收费详情按日期（可选过滤）聚合成 UsageModelAmount，
/// 复用 DeepSeek 现有的数据结构，供 DashboardView / 图表 / 模型分布统一消费。
extension MimoUsageDetailReport {
    /// 按模型聚合为 UsageModelAmount（传 nil 表示不过滤日期）。
    public func asUsageModelAmounts(filteringDates dates: Set<String>? = nil) -> [UsageModelAmount] {
        let filtered = dates.map { target in details.filter { target.contains($0.date) } } ?? details
        var grouped: [String: [String: Int]] = [:]
        for detail in filtered {
            var usage = grouped[detail.model] ?? [:]
            usage["PROMPT_CACHE_HIT_TOKEN", default: 0] += detail.inputHitToken
            usage["PROMPT_CACHE_MISS_TOKEN", default: 0] += detail.inputMissToken
            usage["RESPONSE_TOKEN", default: 0] += detail.outputToken
            usage["REQUEST", default: 0] += detail.requestCount
            grouped[detail.model] = usage
        }
        return grouped.map { UsageModelAmount(model: $0.key, usage: $0.value) }
    }

    /// 按日期聚合成 UsageDayAmount，让 Mimo 数据可直接喂给 MiniChartView。
    public func asUsageDayAmounts() -> [UsageDayAmount] {
        var byDate: [String: [String: [String: Int]]] = [:]
        var dateOrder: [String] = []
        for detail in details {
            if byDate[detail.date] == nil { dateOrder.append(detail.date) }
            var usage = byDate[detail.date]?[detail.model] ?? [:]
            usage["PROMPT_CACHE_HIT_TOKEN", default: 0] += detail.inputHitToken
            usage["PROMPT_CACHE_MISS_TOKEN", default: 0] += detail.inputMissToken
            usage["RESPONSE_TOKEN", default: 0] += detail.outputToken
            usage["REQUEST", default: 0] += detail.requestCount
            byDate[detail.date, default: [:]][detail.model] = usage
        }
        return dateOrder.sorted().map { date in
            let models = byDate[date]!
                .map { UsageModelAmount(model: $0.key, usage: $0.value) }
            return UsageDayAmount(date: date, models: models)
        }
    }

    /// 查询某个模型在（已过滤）详情内的总花费，供 ModelDistributionView 使用。
    public func costForModel(_ model: UsageModelAmount, filteringDates dates: Set<String>? = nil) -> Decimal? {
        let filtered = dates.map { target in details.filter { target.contains($0.date) } } ?? details
        let sum = filtered.filter { $0.model == model.model }.reduce(Decimal.zero) { $0 + $1.consumedAmountDecimal }
        return sum
    }
}

/// 将 Mimo Token Plan 详情聚合成 UsageModelAmount，逻辑与按量收费一致。
extension MimoTokenPlanDetailReport {
    public func asUsageModelAmounts(filteringDates dates: Set<String>? = nil) -> [UsageModelAmount] {
        let filtered = dates.map { target in details.filter { target.contains($0.date) } } ?? details
        var grouped: [String: [String: Int]] = [:]
        for detail in filtered {
            var usage = grouped[detail.model] ?? [:]
            usage["PROMPT_CACHE_HIT_TOKEN", default: 0] += detail.inputHitToken
            usage["PROMPT_CACHE_MISS_TOKEN", default: 0] += detail.inputMissToken
            usage["RESPONSE_TOKEN", default: 0] += detail.outputToken
            usage["REQUEST", default: 0] += detail.requestCount
            grouped[detail.model] = usage
        }
        return grouped.map { UsageModelAmount(model: $0.key, usage: $0.value) }
    }

    /// 按日期聚合成 UsageDayAmount（Token Plan 无金额，只有 token）。
    public func asUsageDayAmounts() -> [UsageDayAmount] {
        var byDate: [String: [String: [String: Int]]] = [:]
        var dateOrder: [String] = []
        for detail in details {
            if byDate[detail.date] == nil { dateOrder.append(detail.date) }
            var usage = byDate[detail.date]?[detail.model] ?? [:]
            usage["PROMPT_CACHE_HIT_TOKEN", default: 0] += detail.inputHitToken
            usage["PROMPT_CACHE_MISS_TOKEN", default: 0] += detail.inputMissToken
            usage["RESPONSE_TOKEN", default: 0] += detail.outputToken
            usage["REQUEST", default: 0] += detail.requestCount
            byDate[detail.date, default: [:]][detail.model] = usage
        }
        return dateOrder.sorted().map { date in
            let models = byDate[date]!
                .map { UsageModelAmount(model: $0.key, usage: $0.value) }
            return UsageDayAmount(date: date, models: models)
        }
    }
}

// MARK: - Cacheable Report Protocol

/// 平台标识符常量
public enum CachePlatform {
    public static let deepseek = "deepseek"
    public static let mimo = "mimo"
}

/// 可缓存报告协议 - 实现此协议即可自动支持缓存
public protocol CacheableReport: Codable {
    /// 平台标识符，用于创建缓存目录
    static var platformIdentifier: String { get }

    /// 数据类型标识符，用于构建缓存文件名
    static var dataTypeIdentifier: String { get }
}

// MARK: - CacheableReport Implementations

extension UsageAmountReport: CacheableReport {
    public static var platformIdentifier: String { CachePlatform.deepseek }
    public static var dataTypeIdentifier: String { "usage" }
}

extension UsageCostReport: CacheableReport {
    public static var platformIdentifier: String { CachePlatform.deepseek }
    public static var dataTypeIdentifier: String { "cost" }
}

extension MimoUsageDetailReport: CacheableReport {
    public static var platformIdentifier: String { CachePlatform.mimo }
    public static var dataTypeIdentifier: String { "usage_detail" }
}

extension MimoTokenPlanDetailReport: CacheableReport {
    public static var platformIdentifier: String { CachePlatform.mimo }
    public static var dataTypeIdentifier: String { "token_plan_detail" }
}
