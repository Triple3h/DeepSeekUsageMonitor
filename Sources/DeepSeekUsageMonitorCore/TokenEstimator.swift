import Foundation

public struct TokenEstimator {
    public init() {}

    public func estimate(_ text: String) -> TokenEstimate {
        var english = 0
        var chinese = 0
        var other = 0

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x4E00...0x9FFF:
                chinese += 1
            case 0x0041...0x005A, 0x0061...0x007A:
                english += 1
            case 0x0009, 0x000A, 0x000D, 0x0020:
                continue
            default:
                other += 1
            }
        }

        return TokenEstimate(
            englishCharacters: english,
            chineseCharacters: chinese,
            otherCharacters: other
        )
    }
}
