import Foundation

public enum UsageCSVParserError: LocalizedError {
    case emptyFile
    case inconsistentColumns

    public var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSV 文件为空。"
        case .inconsistentColumns:
            return "CSV 列数不一致，无法解析。"
        }
    }
}

public struct UsageCSVParser {
    public init() {}

    public func parse(contents: String, sourceName: String) throws -> UsageSummary {
        let rows = try parseCSV(contents)
        guard let header = rows.first, rows.count > 1 else {
            throw UsageCSVParserError.emptyFile
        }

        var summary = UsageSummary(sourceName: sourceName)
        let normalizedHeader = header.map(normalize)
        let dataRows = rows.dropFirst().filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        for row in dataRows {
            guard row.count <= header.count else {
                throw UsageCSVParserError.inconsistentColumns
            }
            var fields: [String: String] = [:]
            for (index, name) in normalizedHeader.enumerated() where index < row.count {
                fields[name] = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let key = firstString(fields, names: ["api_key", "api key", "key", "apikey", "api_key_id"]) ?? "未分组"
            let promptTokens = firstInt(fields, names: ["prompt_tokens", "input_tokens", "input token", "input", "输入tokens", "输入token"]) ?? 0
            let completionTokens = firstInt(fields, names: ["completion_tokens", "output_tokens", "output token", "output", "输出tokens", "输出token"]) ?? 0
            let totalTokens = firstInt(fields, names: ["total_tokens", "tokens", "token_usage", "token usage", "总tokens", "总token"]) ?? (promptTokens + completionTokens)
            let amount = firstDecimal(fields, names: ["amount", "cost", "费用", "金额", "消耗金额"]) ?? 0
            let currency = firstString(fields, names: ["currency", "币种", "货币"]) ?? summary.currency

            summary.rows += 1
            summary.promptTokens += promptTokens
            summary.completionTokens += completionTokens
            summary.totalTokens += totalTokens
            summary.amount += amount
            summary.currency = currency

            var keyUsage = summary.groupedByKey[key] ?? KeyUsage(id: key)
            keyUsage.rows += 1
            keyUsage.promptTokens += promptTokens
            keyUsage.completionTokens += completionTokens
            keyUsage.totalTokens += totalTokens
            keyUsage.amount += amount
            summary.groupedByKey[key] = keyUsage
        }

        return summary
    }

    private func parseCSV(_ contents: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = contents.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isQuoted, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        isQuoted = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    isQuoted.toggle()
                }
            } else if character == "," && !isQuoted {
                row.append(field)
                field = ""
            } else if character == "\n" && !isQuoted {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private func firstString(_ fields: [String: String], names: [String]) -> String? {
        for name in names {
            if let value = fields[normalize(name)], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func firstInt(_ fields: [String: String], names: [String]) -> Int? {
        firstString(fields, names: names).flatMap { Int($0.replacingOccurrences(of: ",", with: "")) }
    }

    private func firstDecimal(_ fields: [String: String], names: [String]) -> Decimal? {
        firstString(fields, names: names).flatMap { Decimal(string: $0.replacingOccurrences(of: ",", with: "")) }
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
    }
}
