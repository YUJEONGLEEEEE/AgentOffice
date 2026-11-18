import SpriteKit
import SwiftUI

/// A small office playing made-up work, for the first-run guides on the Mac and the iPhone.
///
/// It shows what the app does before anything is connected. It reads nothing and sends nothing.
public struct OfficePreviewView: View {

    /// How often people move on to their next step.
    private static let interval: TimeInterval = 1.5

    @State private var scene = OfficeScene(layout: .standard)
    @State private var start = Date.now

    public init() {}

    public var body: some View {
        TimelineView(.periodic(from: .now, by: Self.interval)) { context in
            SpriteView(scene: scene)
                .onChange(of: context.date, initial: true) { _, date in
                    let agents = DemoOffice.state(at: date, startedAt: start).snapshots(at: date)
                    scene.show(agents: OfficeTeam.arrange(agents))
                }
        }
        .aspectRatio(OfficeLayout.standard.size.width / OfficeLayout.standard.size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement()
        .accessibilityLabel(Text("A sample office with people moving between rooms as they work", bundle: .module))
    }
}
