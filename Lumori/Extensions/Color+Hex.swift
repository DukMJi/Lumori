import SwiftUI

extension Color {

    /// Creates a SwiftUI color from a six-character hexadecimal string.
    ///
    /// Both "#7C73E6" and "7C73E6" are accepted.
    init(hex: String) {
        let cleanedHex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&rgbValue)

        let red = Double((rgbValue >> 16) & 0xFF) / 255
        let green = Double((rgbValue >> 8) & 0xFF) / 255
        let blue = Double(rgbValue & 0xFF) / 255

        self.init(
            red: red,
            green: green,
            blue: blue
        )
    }
}
