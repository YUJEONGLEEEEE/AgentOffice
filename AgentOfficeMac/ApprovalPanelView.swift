import AgentOfficeKit
import SwiftUI

/// The permission questions waiting for an answer, shown above the office.
struct ApprovalPanelView: View {

    /// More questions than this are summed up in one line, so the office stays visible.
    private static let visibleLimit = 3

    let model: ApprovalPanelModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(model.requests.prefix(Self.visibleLimit)) { request in
                ApprovalRow(request: request, answer: model.answer)
            }
            if model.requests.count > Self.visibleLimit {
                Text("\(model.requests.count - Self.visibleLimit) more waiting")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
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
                Text("\(request.agentName) wants to use \(request.tool)")
                    .font(.headline)
                Text(request.agentID == nil ? request.project : String(localized: "\(request.project) · team member"))
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
                Button("Allow") { answer(request, .allow) }
                    .buttonStyle(.borderedProminent)
                Button("Deny", role: .destructive) { answer(request, .deny) }
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
