import AgentOfficeKit
import SwiftUI

/// The first-run guide: what the office is, answering permission questions, and privacy.
///
/// It opens once, on the first launch, and again from the floor menu. The office and the question
/// in it are made up on the device: nothing is read from iCloud and nothing is sent.
struct OnboardingView: View {

    /// Whether the guide has been seen, so it opens by itself only once.
    static let seenKey = "hasSeenOnboarding"

    static var hasBeenSeen: Bool {
        get { UserDefaults.standard.bool(forKey: seenKey) }
        set { UserDefaults.standard.set(newValue, forKey: seenKey) }
    }

    let finish: () -> Void

    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(title: "An office where your coding agents work",
                               message: "See the Claude Code sessions on your Mac as people in a pixel-art office. They move to the room for the work they are doing.") {
                    OfficePreviewView()
                }
                .tag(0)

                OnboardingPage(title: "Answer permission questions anywhere",
                               message: "When a session asks to run a command, a notification arrives. Allow or Deny it from the lock screen or Apple Watch.") {
                    SampleQuestion()
                }
                .tag(1)

                OnboardingPage(title: "Private by design",
                               message: "Commands are end-to-end encrypted and kept only in your own iCloud. Get AgentOffice for Mac from the App Store, and sign in with the same Apple Account on both.") {
                    Image(systemName: "lock.icloud.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .accessibilityHidden(true)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < pageCount - 1 ? "Next" : "Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct OnboardingPage<Picture: View>: View {

    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let picture: Picture

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                picture
                    .padding(.top, 32)
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title.bold())
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

/// The real question card, with a made-up question. Answering it only shows that it was answered.
private struct SampleQuestion: View {

    @State private var model = ApprovalPanelModel()
    @State private var answer: ApprovalDecision?

    var body: some View {
        VStack(spacing: 16) {
            ApprovalPanelView(model: model)
            if let answer {
                Label(answer == .allow ? "Allowed: the command runs on your Mac" : "Denied: the command does not run",
                      systemImage: answer == .allow ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(answer == .allow ? .green : .red)
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 200)
        .onAppear(perform: ask)
    }

    private func ask() {
        model.requests = [ApprovalRequest(id: "sample", sessionID: "a7c2d0e1", project: "LunchPicker",
                                          tool: "Bash", summary: "swift test", createdAt: .now)]
        model.answer = { _, decision in
            withAnimation {
                answer = decision
                model.requests = []
            }
            // Ask again after a moment, so the card can be tried more than once.
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation {
                    answer = nil
                    ask()
                }
            }
        }
    }
}
