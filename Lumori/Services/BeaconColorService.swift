import Foundation

// MARK: - Beacon Color Service

/// Generates a stable beacon color from a user's written feeling.
///
/// The same feeling produces the same color. This gives Lumori
/// meaningful color variation now while allowing an AI-powered
/// implementation to replace this service later.
struct BeaconColorService {

    // MARK: - Color Palette

    // These colors are intentionally soft enough for Lumori's
    // dark, quiet visual design.
    private let palette = [
        "#6675D8",
        "#7A6FD1",
        "#A66FAF",
        "#C57776",
        "#D19A61",
        "#C1AC64",
        "#6EAA8C",
        "#609DA1",
        "#5B8FB9",
        "#8477B8",
        "#9B7D68",
        "#718A78"
    ]

    // MARK: - Public Methods

    /// Returns a repeatable hexadecimal color for the supplied feeling.
    func colorHex(for feeling: String) -> String {
        let normalizedFeeling = feeling
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedFeeling.isEmpty else {
            return "#7A6FD1"
        }

        // Swift's built-in hash value changes between app launches,
        // so this simple calculation creates our own stable value.
        let stableValue = normalizedFeeling.unicodeScalars.reduce(0) {
            currentValue,
            scalar in

            (currentValue * 31 + Int(scalar.value)) & 0x7FFFFFFF
        }

        let paletteIndex = stableValue % palette.count

        return palette[paletteIndex]
    }
}
