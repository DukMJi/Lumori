import Foundation

// MARK: - Pairing Code Service

/// Generates and validates short codes used to connect two Lumori users.
struct PairingCodeService {

    // Ambiguous characters such as O, 0, I, and 1 are excluded.
    private let allowedCharacters = Array(
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    )

    private let codeLength = 6

    // MARK: - Generation

    /// Generates a new six-character pairing code.
    func generateCode() -> String {
        String(
            (0..<codeLength).compactMap { _ in
                allowedCharacters.randomElement()
            }
        )
    }

    // MARK: - Validation

    /// Cleans a code entered by the user.
    func normalize(
        _ code: String
    ) -> String {
        let cleanedCharacters = code
            .uppercased()
            .filter {
                allowedCharacters.contains($0)
            }

        return String(
            cleanedCharacters.prefix(codeLength)
        )
    }

    /// Returns whether a pairing code has the expected format.
    func isValid(
        _ code: String
    ) -> Bool {
        normalize(code).count == codeLength
    }
}
