import AppKit
import SwiftUI

/// What the setup guide shows about the events folder. The office window updates it after the user picks a folder.
@MainActor
@Observable
final class SetupGuideState {
    var folderName: String?
}

/// The first-run guide: install the plugin, start a session, then allow the events folder.
///
/// The app never edits the Claude Code settings itself. The plugin adds the hook,
/// and the sandboxed app only reads the folder the user chooses.
struct SetupGuideView: View {

    /// Installs the plugin straight from this project's GitHub repository.
    static let installCommand = "/plugin install agentoffice --marketplace YUJEONGLEEEEE/AgentOffice"
    static let projectURL = URL(string: "https://github.com/YUJEONGLEEEEE/AgentOffice")!

    let state: SetupGuideState
    let chooseFolder: @MainActor () -> Void
    let done: @MainActor () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set Up AgentOffice")
                    .font(.title2.bold())
                Text("Three steps connect your Claude Code sessions to the office.")
                    .foregroundStyle(.secondary)
            }

            step(1, title: "Install the plugin", detail: "In Claude Code, run this command.") {
                // Like a code block: the command fills the box and the copy button sits at its right edge.
                HStack(spacing: 8) {
                    Text(verbatim: Self.installCommand)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                        .accessibilityLabel(Text(verbatim: Self.installCommand))
                    Spacer(minLength: 0)
                    Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc", action: copyCommand)
                        .buttonStyle(.borderless)
                        .font(.body)
                        .fixedSize()
                        .help("Copy the command")
                }
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            step(2, title: "Start a new session",
                 detail: "Open a new Claude Code session, or run /reload-plugins. The events folder is created with the first event.") {
                EmptyView()
            }

            step(3, title: "Allow the events folder",
                 detail: "AgentOffice reads only the folder you choose. Pick Events in ~/Library/Application Support/AgentOffice.") {
                HStack(spacing: 12) {
                    Button(state.folderName == nil ? "Choose Folder…" : "Change Folder…", action: chooseFolder)
                    if let folderName = state.folderName {
                        Label("Connected to \(folderName)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Recorded: the event, tool name, subagent type, project folder name and time.",
                          systemImage: "checkmark.shield")
                    Label("Never recorded: prompts, commands, file contents or full paths.",
                          systemImage: "eye.slash")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack {
                Link("Learn More on GitHub", destination: Self.projectURL)
                Spacer()
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 720)
    }

    private func step(_ number: Int, title: LocalizedStringKey, detail: LocalizedStringKey,
                      @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.callout.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                content()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.installCommand, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
