import AppKit
import SwiftUI
import AgentOfficeKit

/// Hosts the 3D floor and turns the mouse wheel and two-finger scrolling into zoom.
final class FloorHostingView: NSHostingView<FloorView3D> {

    let model: FloorModel3D

    init(model: FloorModel3D) {
        self.model = model
        super.init(rootView: FloorView3D(model: model))
        // Let the layout decide the size, so this view never shrinks the office area.
        sizingOptions = []
    }

    @available(*, unavailable)
    required init(rootView: FloorView3D) {
        fatalError("init(rootView:) is not supported")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.scrollingDeltaY * 0.08
        model.zoom(by: Float(exp(delta)))
    }
}
