import SwiftUI

// MARK: - Beacon Details View

/// Displays the emotional information contained in a beacon entry.
///
/// The current beacon screen can hide the date, while historical
/// lanterns can include it without creating a separate design.
struct BeaconDetailsView: View {

    // MARK: - Properties

    let entry: BeaconEntry

    // Historical entries display their date.
    // The current partner beacon does not need one.
    var showsDate = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            if showsDate {
                dateText
            }

            feelingText

            if let reason = cleanedReason {
                reasonText(reason)
            }

            if !entry.contributions.isEmpty {
                contributionWords
            }
        }
        .frame(maxWidth: 320)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Feeling

    private var feelingText: some View {
        Text(entry.feeling)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
    }

    // MARK: - Reason

    private var cleanedReason: String? {
        guard let reason = entry.reason else {
            return nil
        }

        let cleanedReason = reason.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return cleanedReason.isEmpty ? nil : cleanedReason
    }

    private func reasonText(
        _ reason: String
    ) -> some View {
        Text(reason)
            .font(.body)
            .foregroundStyle(.white.opacity(0.78))
            .lineSpacing(3)
    }

    // MARK: - Contributions

    private var contributionWords: some View {
        FlowingContributionView(
            contributions: entry.contributions
        )
    }

    // MARK: - Date

    private var dateText: some View {
        Text(
            entry.date.formatted(
                date: .long,
                time: .omitted
            )
        )
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.5))
    }
}

// MARK: - Flowing Contribution View

/// Displays contributing words as quiet, compact capsules.
private struct FlowingContributionView: View {

    // MARK: - Properties

    let contributions: [String]

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            ForEach(
                contributions.prefix(3),
                id: \.self
            ) { contribution in
                Text(contribution)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.09))
                    )
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        BeaconDetailsView(
            entry: BeaconEntry(
                feeling: "Overwhelmed",
                reason: "I have a lot to finish before the end of the week.",
                contributions: [
                    "school",
                    "work",
                    "sleep"
                ],
                colorHex: "#6874D8"
            ),
            showsDate: true
        )
    }
}
