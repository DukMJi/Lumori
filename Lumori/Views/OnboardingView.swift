import SwiftUI
import UIKit

// MARK: - Onboarding View

struct OnboardingView: View {

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage("lumori.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    /// True when the introduction is replayed from Settings.
    var isReplay = false

    @State
    private var currentPage = 0

    private let pageCount = 4

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {

                PageCurlView(
                    currentPage: $currentPage,
                    pages: onboardingPages
                )
                .ignoresSafeArea(edges: .top)

                bottomControls
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pages

    private var onboardingPages: [AnyView] {
        [
            AnyView(
                OnboardingPaperPage(
                    number: "I",
                    symbol: "moon.stars",
                    title: "A quieter way\nto stay close",
                    message:
                        "Lumori helps you share how you feel without turning every feeling into a conversation."
                )
            ),

            AnyView(
                OnboardingPaperPage(
                    number: "II",
                    symbol: "light.beacon.max",
                    title: "Your partner’s\nbeacon",
                    message:
                        "Their newest feeling becomes the light in the lighthouse. Tap it to see what they chose to share."
                )
            ),

            AnyView(
                OnboardingPaperPage(
                    number: "III",
                    symbol: "square.and.pencil",
                    title: "Share when\nyou want",
                    message:
                        "Choose a feeling, add what’s contributing to it, and update it whenever you need. Your newest beacon replaces the previous one for that day."
                )
            ),

            AnyView(
                OnboardingPaperPage(
                    number: "IV",
                    symbol: "water.waves",
                    title: "Nothing to\nkeep up with",
                    message:
                        "No streaks. No read receipts. No activity status. No pressure. Previous beacons simply drift into Sea."
                )
            )
        ]
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 14) {

            HStack(spacing: 7) {
                ForEach(
                    0..<pageCount,
                    id: \.self
                ) { index in

                    Circle()
                        .fill(
                            index == currentPage
                                ? Color.white
                                : Color.white.opacity(0.25)
                        )
                        .frame(
                            width: 6,
                            height: 6
                        )
                }
            }

            if currentPage == pageCount - 1 {

                Button {
                    finishOnboarding()
                } label: {
                    Text(
                        isReplay
                            ? "Close"
                            : "Enter Lumori"
                    )
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(
                    Color(
                        hex: "#6874D8"
                    )
                )
                .padding(.horizontal, 28)

            } else {

                Text("Swipe to turn the page")
                    .font(.caption)
                    .foregroundStyle(
                        .white.opacity(0.4)
                    )
                    .frame(height: 48)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(Color.black)
    }

    // MARK: - Finish

    private func finishOnboarding() {
        hasCompletedOnboarding = true

        if isReplay {
            dismiss()
        }
    }
}

// MARK: - Paper Page

private struct OnboardingPaperPage: View {

    let number: String
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ZStack {

            paperBackground

            decorativeMarks

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                HStack {
                    Text("LUMORI")
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold,
                                design: .serif
                            )
                        )
                        .tracking(3)

                    Spacer()

                    Text(number)
                        .font(
                            .system(
                                size: 12,
                                weight: .medium,
                                design: .serif
                            )
                        )
                }
                .foregroundStyle(
                    ink.opacity(0.55)
                )

                Spacer()

                Image(systemName: symbol)
                    .font(
                        .system(
                            size: 34,
                            weight: .light
                        )
                    )
                    .foregroundStyle(
                        ink.opacity(0.72)
                    )
                    .padding(.bottom, 28)

                Text(title)
                    .font(
                        .system(
                            size: 38,
                            weight: .medium,
                            design: .serif
                        )
                    )
                    .foregroundStyle(ink)
                    .lineSpacing(2)

                Rectangle()
                    .fill(
                        ink.opacity(0.18)
                    )
                    .frame(
                        width: 42,
                        height: 1
                    )
                    .padding(.vertical, 24)

                Text(message)
                    .font(
                        .system(
                            size: 18,
                            weight: .regular,
                            design: .serif
                        )
                    )
                    .foregroundStyle(
                        ink.opacity(0.72)
                    )
                    .lineSpacing(7)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Spacer()

                Text("A small space for two.")
                    .font(
                        .system(
                            size: 12,
                            weight: .regular,
                            design: .serif
                        )
                    )
                    .italic()
                    .foregroundStyle(
                        ink.opacity(0.38)
                    )
            }
            .padding(.horizontal, 36)
            .padding(.top, 66)
            .padding(.bottom, 44)
        }
        .clipped()
    }

    // MARK: - Colors

    private var ink: Color {
        Color(
            red: 31 / 255,
            green: 40 / 255,
            blue: 58 / 255
        )
    }

    // MARK: - Background

    private var paperBackground: some View {
        ZStack {

            Color(
                red: 239 / 255,
                green: 234 / 255,
                blue: 218 / 255
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.20),
                    Color.clear,
                    Color.black.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.035)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // MARK: - Decoration

    private var decorativeMarks: some View {
        GeometryReader { geometry in

            ZStack {

                Circle()
                    .stroke(
                        ink.opacity(0.035),
                        lineWidth: 1
                    )
                    .frame(
                        width: 240,
                        height: 240
                    )
                    .offset(
                        x: geometry.size.width * 0.46,
                        y: -80
                    )

                Circle()
                    .fill(
                        ink.opacity(0.02)
                    )
                    .frame(
                        width: 300,
                        height: 300
                    )
                    .offset(
                        x: -170,
                        y: geometry.size.height * 0.72
                    )

                Rectangle()
                    .fill(
                        Color.black.opacity(0.025)
                    )
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .offset(
                        x: geometry.size.width / 2 - 8
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Page Curl View

private struct PageCurlView: UIViewControllerRepresentable {

    @Binding
    var currentPage: Int

    let pages: [AnyView]

    func makeCoordinator() -> Coordinator {
        Coordinator(
            parent: self
        )
    }

    func makeUIViewController(
        context: Context
    ) -> UIPageViewController {

        let controller =
            UIPageViewController(
                transitionStyle: .pageCurl,
                navigationOrientation: .horizontal,
                options: nil
            )

        controller.dataSource =
            context.coordinator

        controller.delegate =
            context.coordinator

        controller.isDoubleSided = false

        context.coordinator
            .buildControllers(
                from: pages
            )

        if let firstController =
            context.coordinator.controllers.first {

            controller.setViewControllers(
                [firstController],
                direction: .forward,
                animated: false
            )
        }

        return controller
    }

    func updateUIViewController(
        _ pageViewController: UIPageViewController,
        context: Context
    ) {
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    final class Coordinator:
        NSObject,
        UIPageViewControllerDataSource,
        UIPageViewControllerDelegate {

        var parent: PageCurlView

        var controllers:
            [UIViewController] = []

        init(
            parent: PageCurlView
        ) {
            self.parent = parent
        }

        func buildControllers(
            from pages: [AnyView]
        ) {
            controllers =
                pages.map { page in
                    UIHostingController(
                        rootView: page
                    )
                }
        }

        // MARK: Previous Page

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {

            guard let index =
                controllers.firstIndex(
                    where: {
                        $0 === viewController
                    }
                )
            else {
                return nil
            }

            let previousIndex =
                index - 1

            guard
                controllers.indices.contains(
                    previousIndex
                )
            else {
                return nil
            }

            return controllers[
                previousIndex
            ]
        }

        // MARK: Next Page

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {

            guard let index =
                controllers.firstIndex(
                    where: {
                        $0 === viewController
                    }
                )
            else {
                return nil
            }

            let nextIndex =
                index + 1

            guard
                controllers.indices.contains(
                    nextIndex
                )
            else {
                return nil
            }

            return controllers[
                nextIndex
            ]
        }

        // MARK: Page Completed

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {

            guard completed,
                  let visibleController =
                    pageViewController
                        .viewControllers?
                        .first,
                  let index =
                    controllers.firstIndex(
                        where: {
                            $0 === visibleController
                        }
                    )
            else {
                return
            }

            parent.currentPage =
                index
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
