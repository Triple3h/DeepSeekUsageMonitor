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
