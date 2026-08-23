import SwiftUI

// MARK: - Launch Container View

/// Displays Lumori's brief launch overlay above the live application.
///
/// The application is loaded immediately underneath the overlay.
/// Once the launch transition finishes, the overlay is removed.
struct LaunchContainerView<Content: View>: View {

    // MARK: - State

    @State private var isShowingLaunchOverlay = true

    // MARK: - Content

    private let content: Content

    // MARK: - Initialization

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Keep the real app loaded from the beginning.
            content

            if isShowingLaunchOverlay {
                LaunchOverlayView {
                    finishLaunchTransition()
                }
                .zIndex(10)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    // MARK: - Transition

    private func finishLaunchTransition() {
        isShowingLaunchOverlay = false
    }
}

// MARK: - Preview

#Preview {
    LaunchContainerView {
        LinearGradient(
            colors: [
                .black,
                .indigo.opacity(0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
