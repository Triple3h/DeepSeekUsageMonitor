import Foundation

public enum PlatformSummaryClientError: LocalizedError {
    case missingBearerToken
    case invalidResponse
    case apiError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .missingBearerToken:
            return "请先在设置中保存平台 Bearer Token。"
        case .invalidResponse:
            return "平台摘要接口返回了无法解析的响应。"
        case let .apiError(statusCode, body):
            return "平台摘要接口请求失败（HTTP \(statusCode)）：\(body)"
        }
    }
}

public final class PlatformSummaryClient {
    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://platform.deepseek.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func fetchUserSummary(bearerToken: String, cookie: String?) async throws -> UserSummaryReport {
        let endpoint = baseURL.appending(path: "api/v0/users/get_user_summary")
        let data = try await fetchData(endpoint: endpoint, bearerToken: bearerToken, cookie: cookie)
        return try UserSummaryParser().parse(data: data, endpoint: endpoint)
    }

    public func fetchUsageAmount(month: Int, year: Int, bearerToken: String, cookie: String?) async throws -> UsageAmountReport {
        var components = URLComponents(url: baseURL.appending(path: "api/v0/usage/amount"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "month", value: String(month)),
            URLQueryItem(name: "year", value: String(year))
        ]
        let data = try await fetchData(endpoint: components.url!, bearerToken: bearerToken, cookie: cookie)
        return try UsageAmountParser().parse(data: data, endpoint: components.url!)
    }

    public func fetchUsageCost(month: Int, year: Int, bearerToken: String, cookie: String?) async throws -> UsageCostReport {
        var components = URLComponents(url: baseURL.appending(path: "api/v0/usage/cost"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "month", value: String(month)),
            URLQueryItem(name: "year", value: String(year))
        ]
        let data = try await fetchData(endpoint: components.url!, bearerToken: bearerToken, cookie: cookie)
        return try UsageCostParser().parse(data: data, endpoint: components.url!)
    }

    private func fetchData(endpoint: URL, bearerToken: String, cookie: String?) async throws -> Data {
        let token = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw PlatformSummaryClientError.missingBearerToken
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://platform.deepseek.com/usage", forHTTPHeaderField: "Referer")
        request.setValue("1.0.0", forHTTPHeaderField: "X-App-Version")
        if let cookie, !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlatformSummaryClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "无响应正文"
            throw PlatformSummaryClientError.apiError(httpResponse.statusCode, body)
        }

        return data
    }
}

public struct UserSummaryParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> UserSummaryReport {
        let response = try JSONDecoder().decode(UserSummaryResponse.self, from: data)
        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""
        let bizData = response.data.bizData

        return UserSummaryReport(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            currentToken: bizData.currentToken,
            monthlyUsage: Int(bizData.monthlyUsage) ?? 0,
            totalUsage: bizData.totalUsage,
            normalWallets: bizData.normalWallets.map { PlatformWallet(currency: $0.currency, balance: $0.balance, tokenEstimation: $0.tokenEstimation) },
            bonusWallets: bizData.bonusWallets.map { PlatformWallet(currency: $0.currency, balance: $0.balance, tokenEstimation: $0.tokenEstimation) },
            monthlyCosts: bizData.monthlyCosts.map { PlatformCost(currency: $0.currency, amount: $0.amount) },
            totalAvailableTokenEstimation: Int(bizData.totalAvailableTokenEstimation) ?? 0
        )
    }
}

private struct UserSummaryResponse: Decodable {
    let data: UserSummaryEnvelope
}

private struct UserSummaryEnvelope: Decodable {
    let bizData: UserSummaryBizData

    enum CodingKeys: String, CodingKey {
        case bizData = "biz_data"
    }
}

private struct UserSummaryBizData: Decodable {
    let currentToken: Int
    let monthlyUsage: String
    let totalUsage: Int
    let normalWallets: [UserSummaryWallet]
    let bonusWallets: [UserSummaryWallet]
    let monthlyCosts: [UserSummaryCost]
    let totalAvailableTokenEstimation: String

    enum CodingKeys: String, CodingKey {
        case currentToken = "current_token"
        case monthlyUsage = "monthly_usage"
        case totalUsage = "total_usage"
        case normalWallets = "normal_wallets"
        case bonusWallets = "bonus_wallets"
        case monthlyCosts = "monthly_costs"
        case totalAvailableTokenEstimation = "total_available_token_estimation"
    }
}

private struct UserSummaryWallet: Decodable {
    let currency: String
    let balance: String
    let tokenEstimation: String

    enum CodingKeys: String, CodingKey {
        case currency
        case balance
        case tokenEstimation = "token_estimation"
    }
}

private struct UserSummaryCost: Decodable {
    let currency: String
    let amount: String
}

public struct UsageAmountParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> UsageAmountReport {
        let response = try JSONDecoder().decode(UsageAmountResponse.self, from: data)
        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""
        let bizData = response.data.bizData

        return UsageAmountReport(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            models: bizData.total.map(\.domainModel),
            days: bizData.days.map { UsageDayAmount(date: $0.date, models: $0.data.map(\.domainModel)) }
        )
    }
}

private struct UsageAmountResponse: Decodable {
    let data: UsageAmountEnvelope
}

private struct UsageAmountEnvelope: Decodable {
    let bizData: UsageAmountBizData

    enum CodingKeys: String, CodingKey {
        case bizData = "biz_data"
    }
}

private struct UsageAmountBizData: Decodable {
    let total: [UsageAmountModel]
    let days: [UsageAmountDay]
}

private struct UsageAmountDay: Decodable {
    let date: String
    let data: [UsageAmountModel]
}

private struct UsageAmountModel: Decodable {
    let model: String
    let usage: [UsageAmountEntry]

    var domainModel: UsageModelAmount {
        UsageModelAmount(
            model: model,
            usage: Dictionary(uniqueKeysWithValues: usage.map { ($0.type, $0.intAmount) })
        )
    }
}

private struct UsageAmountEntry: Decodable {
    let type: String
    let amount: String

    var intAmount: Int {
        Int(amount) ?? 0
    }
}

public struct UsageCostParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> UsageCostReport {
        let response = try JSONDecoder().decode(UsageCostResponse.self, from: data)
        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""
        let bizData = response.data.bizData.first

        return UsageCostReport(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            currency: bizData?.currency ?? "CNY",
            models: bizData?.total.map(\.domainModel) ?? [],
            days: bizData?.days.map { UsageCostDayAmount(date: $0.date, models: $0.data.map(\.domainModel)) } ?? []
        )
    }
}

private struct UsageCostResponse: Decodable {
    let data: UsageCostEnvelope
}

private struct UsageCostEnvelope: Decodable {
    let bizData: [UsageCostBizData]

    enum CodingKeys: String, CodingKey {
        case bizData = "biz_data"
    }
}

private struct UsageCostBizData: Decodable {
    let total: [UsageCostModel]
    let days: [UsageCostDay]
    let currency: String
}

private struct UsageCostDay: Decodable {
    let date: String
    let data: [UsageCostModel]
}

private struct UsageCostModel: Decodable {
    let model: String
    let usage: [UsageCostEntry]

    var domainModel: UsageCostModelAmount {
        UsageCostModelAmount(
            model: model,
            usage: Dictionary(uniqueKeysWithValues: usage.map { ($0.type, $0.decimalAmount) })
        )
    }
}

private struct UsageCostEntry: Decodable {
    let type: String
    let amount: String

    var decimalAmount: Decimal {
        Decimal(string: amount) ?? 0
    }
}

public struct PlatformSummaryParser {
    private let interestingKeyParts = [
        "token",
        "balance",
        "usage",
        "used",
        "quota",
        "amount",
        "cost",
        "credit",
        "remain",
        "left",
        "limit",
        "total",
        "余额",
        "用量",
        "费用",
        "金额"
    ]

    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> PlatformSummary {
        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""
        let metrics = collectMetrics(from: object, path: "$")
        return PlatformSummary(endpoint: endpoint, capturedAt: capturedAt, rawJSON: rawJSON, metrics: metrics)
    }

    private func collectMetrics(from value: Any, path: String) -> [PlatformMetric] {
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().flatMap { key in
                collectMetrics(from: dictionary[key] as Any, path: "\(path).\(key)")
            }
        }

        if let array = value as? [Any] {
            return array.enumerated().flatMap { index, item in
                collectMetrics(from: item, path: "\(path)[\(index)]")
            }
        }

        guard isInteresting(path: path) else {
            return []
        }

        return [PlatformMetric(path: path, value: displayValue(value))]
    }

    private func isInteresting(path: String) -> Bool {
        let lowercased = path.lowercased()
        return interestingKeyParts.contains { lowercased.contains($0.lowercased()) }
    }

    private func displayValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case is NSNull:
            return "null"
        default:
            return String(describing: value)
        }
    }
}
