import Foundation

public enum MimoClientError: LocalizedError {
    case missingCookie
    case invalidCookie
    case invalidResponse
    case apiError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .missingCookie:
            return "请先在设置中保存 Mimo 平台 Cookie。"
        case .invalidCookie:
            return "Cookie 格式无效，请粘贴完整的 Cookie 字符串。"
        case .invalidResponse:
            return "Mimo 平台接口返回了无法解析的响应。"
        case let .apiError(statusCode, body):
            return "Mimo 平台接口请求失败（HTTP \(statusCode)）：\(body)"
        }
    }
}

public final class MimoClient {
    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://platform.xiaomimimo.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    /// 获取使用情况概览 (GET /api/v1/usage)
    public func fetchUsageOverview(cookieString: String) async throws -> MimoUsageOverview {
        let endpoint = baseURL.appending(path: "api/v1/usage")
        let data = try await fetchData(endpoint: endpoint, cookieString: cookieString, method: "GET")
        return try MimoUsageOverviewParser().parse(data: data, endpoint: endpoint)
    }

    /// 获取按量收费详情列表 (POST /api/v1/usage/detail/list)
    public func fetchUsageDetailList(month: Int, year: Int, cookieString: String) async throws -> MimoUsageDetailReport {
        let endpoint = baseURL.appending(path: "api/v1/usage/detail/list")
        let requestBody = MimoUsageRequest(year: year, month: month)
        let bodyData = try JSONEncoder().encode(requestBody)
        let data = try await fetchData(endpoint: endpoint, cookieString: cookieString, method: "POST", body: bodyData)
        return try MimoUsageDetailParser().parse(data: data, endpoint: endpoint)
    }

    /// 获取 Token Plan 使用情况 (GET /api/v1/tokenPlan/usage)
    public func fetchTokenPlanUsage(cookieString: String) async throws -> MimoTokenPlanUsage {
        let endpoint = baseURL.appending(path: "api/v1/tokenPlan/usage")
        let data = try await fetchData(endpoint: endpoint, cookieString: cookieString, method: "GET")
        return try MimoTokenPlanUsageParser().parse(data: data, endpoint: endpoint)
    }

    /// 获取 Token Plan 详情列表 (POST /api/v1/usage/token-plan/list)
    public func fetchTokenPlanDetailList(month: Int, year: Int, cookieString: String) async throws -> MimoTokenPlanDetailReport {
        let endpoint = baseURL.appending(path: "api/v1/usage/token-plan/list")
        let requestBody = MimoUsageRequest(year: year, month: month)
        let bodyData = try JSONEncoder().encode(requestBody)
        let data = try await fetchData(endpoint: endpoint, cookieString: cookieString, method: "POST", body: bodyData)
        return try MimoTokenPlanDetailParser().parse(data: data, endpoint: endpoint)
    }

    /// 获取账户余额 (GET /api/v1/balance)
    public func fetchBalance(cookieString: String) async throws -> MimoBalanceReport {
        let endpoint = baseURL.appending(path: "api/v1/balance")
        let data = try await fetchData(endpoint: endpoint, cookieString: cookieString, method: "GET")
        return try MimoBalanceParser().parse(data: data, endpoint: endpoint)
    }

    private func fetchData(endpoint: URL, cookieString: String, method: String, body: Data? = nil) async throws -> Data {
        // 解析 cookie 字符串
        let cookie = MimoCookie.parse(cookieString)
        guard let cookie else {
            throw MimoClientError.invalidCookie
        }

        // 将 api-platform_ph 作为 URL 查询参数附加（服务端要求）
        // 注意：URLQueryItem 不会编码 +，但服务端会将 + 解读为空格，需手动编码
        var requestURL = endpoint
        if let ph = cookie.apiPlatformPh, !ph.isEmpty,
           var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) {
            let encodedPH = ph.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ph
            components.percentEncodedQuery = (components.percentEncodedQuery ?? "") +
                (components.percentEncodedQuery == nil ? "" : "&") +
                "api-platform_ph=\(encodedPH)"
            if let newURL = components.url {
                requestURL = newURL
            }
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(cookie.cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://platform.xiaomimimo.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://platform.xiaomimimo.com", forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Asia/Shanghai", forHTTPHeaderField: "x-timezone")

        if let body = body {
            request.httpBody = body
        }

        #if DEBUG
        print("\n========== Mimo API Request ==========")
        print("📍 URL: \(requestURL.absoluteString)")
        print("📌 Method: \(method)")
        print("🍪 Cookie: \(cookie.cookieHeader)")
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            print("📦 Body: \(bodyString)")
        }
        print("========================================\n")
        #endif

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MimoClientError.invalidResponse
        }

        #if DEBUG
        print("\n========== Mimo API Response ==========")
        print("📍 URL: \(endpoint.absoluteString)")
        print("📊 Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = String(responseString.prefix(500))
            print("📄 Response: \(preview)\(responseString.count > 500 ? "..." : "")")
        }
        print("=========================================\n")
        #endif

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "无响应正文"
            throw MimoClientError.apiError(httpResponse.statusCode, bodyText)
        }

        return data
    }
}

// MARK: - Request Models

private struct MimoUsageRequest: Encodable {
    let year: Int
    let month: Int
}

// MARK: - Response Models

private struct MimoOverviewResponse: Decodable {
    let code: Int
    let message: String
    let data: MimoOverviewData
}

private struct MimoOverviewData: Decodable {
    let tokenUsage: MimoTokenUsageData
    let accountRateLimit: MimoAccountRateLimitData
    let costUsage: MimoCostUsageData
    let pluginUsage: MimoPluginUsageData

    enum CodingKeys: String, CodingKey {
        case tokenUsage = "tokenUsage"
        case accountRateLimit = "accountRateLimit"
        case costUsage = "costUsage"
        case pluginUsage = "pluginUsage"
    }
}

private struct MimoTokenUsageData: Decodable {
    let inputToken: Int
    let outputToken: Int
    let cacheToken: Int
    let totalToken: Int
    let inputAudioDuration: Int
}

private struct MimoAccountRateLimitData: Decodable {
    let tpm: Int
    let rpm: Int
    let queryTpm: Int
    let concurrency: Int
}

private struct MimoCostUsageData: Decodable {
    let totalCost: String
    let currentMonthCost: String
}

private struct MimoPluginUsageData: Decodable {
    let totalRequestCount: String
    let webSearchRequestCount: String
}

private struct MimoDetailListResponse: Decodable {
    let code: Int
    let message: String
    let data: [MimoDetailData]
}

private struct MimoDetailData: Decodable {
    let date: String
    let model: String
    let apiKey: String
    let currency: String
    let consumedAmount: String
    let inputHitAmount: String
    let inputMissAmount: String
    let outputAmount: String
    let totalToken: Int
    let inputHitToken: Int
    let inputMissToken: Int
    let outputToken: Int
    let requestCount: Int
    let inputAudioDuration: Int
}

private struct MimoTokenPlanUsageResponse: Decodable {
    let code: Int
    let message: String
    let data: MimoTokenPlanUsageData
}

private struct MimoTokenPlanUsageData: Decodable {
    let monthUsage: MimoTokenPlanMonthUsageData
    let usage: MimoTokenPlanTotalUsageData
}

private struct MimoTokenPlanMonthUsageData: Decodable {
    let percent: Double
    let items: [MimoTokenPlanUsageItemData]
}

private struct MimoTokenPlanTotalUsageData: Decodable {
    let percent: Double
    let items: [MimoTokenPlanUsageItemData]
}

private struct MimoTokenPlanUsageItemData: Decodable {
    let name: String
    let used: Int
    let limit: Int
    let percent: Double
}

private struct MimoTokenPlanDetailListResponse: Decodable {
    let code: Int
    let message: String
    let data: [MimoTokenPlanDetailData]
}

private struct MimoTokenPlanDetailData: Decodable {
    let date: String
    let model: String
    let totalToken: Int
    let inputHitToken: Int
    let inputMissToken: Int
    let outputToken: Int
    let requestCount: Int
    let inputAudioDuration: Int
}

private struct MimoBalanceResponse: Decodable {
    let code: Int
    let message: String
    let data: MimoBalanceData
}

private struct MimoBalanceData: Decodable {
    let balance: String
    let frozenBalance: String
    let currency: String
    let giftBalance: String
    let cashBalance: String
}

// MARK: - Parsers

public struct MimoUsageOverviewParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> MimoUsageOverview {
        let response = try JSONDecoder().decode(MimoOverviewResponse.self, from: data)
        guard response.code == 0 else {
            throw MimoClientError.apiError(response.code, response.message)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""

        let tokenUsage = MimoTokenUsage(
            inputToken: response.data.tokenUsage.inputToken,
            outputToken: response.data.tokenUsage.outputToken,
            cacheToken: response.data.tokenUsage.cacheToken,
            totalToken: response.data.tokenUsage.totalToken,
            inputAudioDuration: response.data.tokenUsage.inputAudioDuration
        )

        let rateLimit = MimoAccountRateLimit(
            tpm: response.data.accountRateLimit.tpm,
            rpm: response.data.accountRateLimit.rpm,
            queryTpm: response.data.accountRateLimit.queryTpm,
            concurrency: response.data.accountRateLimit.concurrency
        )

        let costUsage = MimoCostUsage(
            totalCost: response.data.costUsage.totalCost,
            currentMonthCost: response.data.costUsage.currentMonthCost
        )

        let pluginUsage = MimoPluginUsage(
            totalRequestCount: response.data.pluginUsage.totalRequestCount,
            webSearchRequestCount: response.data.pluginUsage.webSearchRequestCount
        )

        return MimoUsageOverview(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            tokenUsage: tokenUsage,
            accountRateLimit: rateLimit,
            costUsage: costUsage,
            pluginUsage: pluginUsage
        )
    }
}

public struct MimoUsageDetailParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> MimoUsageDetailReport {
        let response = try JSONDecoder().decode(MimoDetailListResponse.self, from: data)
        guard response.code == 0 else {
            throw MimoClientError.apiError(response.code, response.message)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""

        let details = response.data.map { item in
            MimoUsageDetail(
                date: item.date,
                model: item.model,
                apiKey: item.apiKey,
                currency: item.currency,
                consumedAmount: item.consumedAmount,
                inputHitAmount: item.inputHitAmount,
                inputMissAmount: item.inputMissAmount,
                outputAmount: item.outputAmount,
                totalToken: item.totalToken,
                inputHitToken: item.inputHitToken,
                inputMissToken: item.inputMissToken,
                outputToken: item.outputToken,
                requestCount: item.requestCount,
                inputAudioDuration: item.inputAudioDuration
            )
        }

        let currency = details.first?.currency ?? "CNY"

        return MimoUsageDetailReport(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            currency: currency,
            details: details
        )
    }
}

public struct MimoTokenPlanUsageParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> MimoTokenPlanUsage {
        let response = try JSONDecoder().decode(MimoTokenPlanUsageResponse.self, from: data)
        guard response.code == 0 else {
            throw MimoClientError.apiError(response.code, response.message)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""

        let monthItems = response.data.monthUsage.items.map { item in
            MimoTokenPlanUsageItem(name: item.name, used: item.used, limit: item.limit, percent: item.percent)
        }

        let monthUsage = MimoTokenPlanMonthUsage(
            percent: response.data.monthUsage.percent,
            items: monthItems
        )

        let totalItems = response.data.usage.items
        guard let planItem = totalItems.first(where: { $0.name == "plan_total_token" }),
              let compItem = totalItems.first(where: { $0.name == "compensation_total_token" }) else {
            throw MimoClientError.invalidResponse
        }

        let planTokenItem = MimoTokenPlanUsageItem(
            name: planItem.name,
            used: planItem.used,
            limit: planItem.limit,
            percent: planItem.percent
        )

        let compTokenItem = MimoTokenPlanUsageItem(
            name: compItem.name,
            used: compItem.used,
            limit: compItem.limit,
            percent: compItem.percent
        )

        let usage = MimoTokenPlanTotalUsage(
            percent: response.data.usage.percent,
            planTotalToken: planTokenItem,
            compensationTotalToken: compTokenItem
        )

        return MimoTokenPlanUsage(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            monthUsage: monthUsage,
            usage: usage
        )
    }
}

public struct MimoTokenPlanDetailParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> MimoTokenPlanDetailReport {
        let response = try JSONDecoder().decode(MimoTokenPlanDetailListResponse.self, from: data)
        guard response.code == 0 else {
            throw MimoClientError.apiError(response.code, response.message)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""

        let details = response.data.map { item in
            MimoTokenPlanDetail(
                date: item.date,
                model: item.model,
                totalToken: item.totalToken,
                inputHitToken: item.inputHitToken,
                inputMissToken: item.inputMissToken,
                outputToken: item.outputToken,
                requestCount: item.requestCount,
                inputAudioDuration: item.inputAudioDuration
            )
        }

        return MimoTokenPlanDetailReport(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            details: details
        )
    }
}

public struct MimoBalanceParser {
    public init() {}

    public func parse(data: Data, endpoint: URL, capturedAt: Date = Date()) throws -> MimoBalanceReport {
        let response = try JSONDecoder().decode(MimoBalanceResponse.self, from: data)
        guard response.code == 0 else {
            throw MimoClientError.apiError(response.code, response.message)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let rawJSON = String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""

        func decimal(_ s: String) -> Decimal { Decimal(string: s) ?? 0 }

        return MimoBalanceReport(
            endpoint: endpoint,
            capturedAt: capturedAt,
            rawJSON: rawJSON,
            currency: response.data.currency,
            balance: decimal(response.data.balance),
            giftBalance: decimal(response.data.giftBalance),
            cashBalance: decimal(response.data.cashBalance),
            frozenBalance: decimal(response.data.frozenBalance)
        )
    }
}