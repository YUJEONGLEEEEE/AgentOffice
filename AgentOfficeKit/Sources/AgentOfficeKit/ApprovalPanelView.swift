import Observation
import SwiftUI

/// The open permission questions, for the panel above the office.
@MainActor
@Observable
public final class ApprovalPanelModel {
    public var requests: [ApprovalRequest] = []
    public var answer: (ApprovalRequest, ApprovalDecision) -> Void = { _, _ in }

    public init() {}
}

/// The permission questions waiting for an answer, shown above the office on the Mac and the iPhone.
public struct ApprovalPanelView: View {

    /// More questions than this are summed up in one line, so the office stays visible.
    private static let visibleLimit = 3

    let model: ApprovalPanelModel

    public init(model: ApprovalPanelModel) {
        self.model = model
    }

    public var body: some View {
        // Nothing at all while no one is waiting, so the panel takes no space.
        if !model.requests.isEmpty {
            VStack(spacing: 8) {
                ForEach(model.requests.prefix(Self.visibleLimit)) { request in
                    ApprovalRow(request: request, answer: model.answer)
                }
                if model.requests.count > Self.visibleLimit {
                    Text("\(model.requests.count - Self.visibleLimit) more waiting", bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
    }
}

private struct ApprovalRow: View {

    let request: ApprovalRequest
    let answer: (ApprovalRequest, ApprovalDecision) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(request.agentName) wants to use \(request.tool)", bundle: .module)
                    .font(.headline)
                Text(request.agentID == nil ? request.project : String(localized: "\(request.project) · team member", bundle: .module))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !request.summary.isEmpty {
                    Text(verbatim: request.summary)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        .help(request.summary)
                }
            }

            VStack(spacing: 6) {
                Button { answer(request, .allow) } label: { Text("Allow", bundle: .module) }
                    .buttonStyle(.borderedProminent)
                Button(role: .destructive) { answer(request, .deny) } label: { Text("Deny", bundle: .module) }
            }
            .controlSize(.large)
            .fixedSize()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.6)))
        .accessibilityElement(children: .contain)
    }
}
