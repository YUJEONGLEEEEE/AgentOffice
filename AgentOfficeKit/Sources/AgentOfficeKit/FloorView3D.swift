import RealityKit
import SwiftUI

/// What the 3D floor shows and where the camera is. The apps set `agents`; the view handles the rest.
@MainActor
@Observable
public final class FloorModel3D {

    /// Everyone on the floor, including team members waiting at their desks.
    public var agents: [AgentSnapshot] = []
    /// The agent whose card is open.
    public var selectedID: String?

    public private(set) var yaw: Float = .pi / 4
    public private(set) var pitch: Float = 0.75
    public private(set) var zoom: Float = 1

    static let pitchRange: ClosedRange<Float> = 0.3...1.4
    static let zoomRange: ClosedRange<Float> = 0.6...3

    public init() {}

    /// Turns the camera. Positive `dx` turns to the right; positive `dy` looks more from above.
    public func turn(dx: Float, dy: Float) {
        yaw -= dx
        pitch = min(Self.pitchRange.upperBound, max(Self.pitchRange.lowerBound, pitch + dy))
    }

    /// Zooms by a factor: above 1 moves closer.
    public func zoom(by factor: Float) {
        zoom = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom * factor))
    }

    /// Back to the view the floor opens with.
    public func resetCamera() {
        yaw = .pi / 4
        pitch = 0.75
        zoom = 1
        selectedID = nil
    }

    var selectedAgent: AgentSnapshot? {
        selectedID.flatMap { id in agents.first { $0.id == id } }
    }
}

/// One floor of the office in 3D. Drag to turn, pinch to zoom, and click or tap a person for their card.
public struct FloorView3D: View {

    @Bindable private var model: FloorModel3D
    @State private var scene = FloorScene3D()
    @State private var dragStart: CGSize?
    @State private var zoomStart: CGFloat?

    public init(model: FloorModel3D) {
        self.model = model
    }

    public var body: some View {
        // Read here so SwiftUI updates the RealityView when they change.
        let agents = model.agents
        let camera = (model.yaw, model.pitch, model.zoom)

        RealityView { content in
            content.add(scene.root)
            content.add(scene.camera)
            scene.setCamera(yaw: camera.0, pitch: camera.1, zoom: camera.2)
            scene.update(agents: agents)
        } update: { _ in
            scene.setCamera(yaw: camera.0, pitch: camera.1, zoom: camera.2)
            scene.update(agents: agents)
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    let previous = dragStart ?? .zero
                    model.turn(dx: Float(value.translation.width - previous.width) * 0.008,
                               dy: Float(value.translation.height - previous.height) * 0.006)
                    dragStart = value.translation
                }
                .onEnded { _ in dragStart = nil }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let previous = zoomStart ?? 1
                    model.zoom(by: Float(value.magnification / previous))
                    zoomStart = value.magnification
                }
                .onEnded { _ in zoomStart = nil }
        )
        .simultaneousGesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    model.selectedID = scene.agentID(for: value.entity)
                }
        )
        .background(Color(red: 0.106, green: 0.133, blue: 0.2))
        .overlay(alignment: .topTrailing) {
            if let agent = model.selectedAgent {
                AgentCard3D(agent: agent) { model.selectedID = nil }
                    .padding(12)
            }
        }
        .overlay(alignment: .bottom) {
            Text(String(localized: "Drag to turn · Pinch or scroll to zoom · Click a person for details", bundle: .module))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45), in: Capsule())
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Floor in 3D", bundle: .module))
    }
}

/// The card for a person picked in the 3D floor.
private struct AgentCard3D: View {
    let agent: AgentSnapshot
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName).font(.headline)
                Text(agent.status == .left ? OfficeText.outOfOffice : agent.room.displayName)
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(agent.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color(hex: agent.status.tagColor), in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(Color(hex: agent.status.tagTextColor))
            }
            Button(action: close) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Close", bundle: .module))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
