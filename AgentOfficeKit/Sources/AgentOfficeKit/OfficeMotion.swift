#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Shared timing for moving between the building and a floor.
public enum OfficeMotion {

    /// How long the building takes to zoom into or out of a floor.
    public static let zoomDuration: TimeInterval = 0.35
    /// How long the 3D floor takes to settle after it opens.
    public static let entranceDuration: TimeInterval = 0.5

    /// True when the person turned on Reduce Motion. Views then change without zooming.
    @MainActor
    public static var prefersReducedMotion: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// Ease in and out, for a progress from 0 to 1.
    static func easeInOut(_ t: Double) -> Double {
        let t = min(1, max(0, t))
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
