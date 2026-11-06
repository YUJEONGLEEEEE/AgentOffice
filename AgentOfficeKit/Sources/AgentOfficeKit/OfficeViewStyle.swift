import Foundation

/// How the office is shown. Each device remembers its own choice.
public enum OfficeViewStyle: String, CaseIterable, Sendable {
    /// The top-down floor plan of one office.
    case flat = "2d"
    /// The building: every project as a floor, and a floor opens when picked.
    case building = "3d"

    /// The short label on the switch. The same in every language.
    public var title: String {
        switch self {
        case .flat: "2D"
        case .building: "3D"
        }
    }

    /// What the switch does, for VoiceOver.
    public var accessibilityLabel: String {
        switch self {
        case .flat: String(localized: "Show the floor plan", bundle: .module)
        case .building: String(localized: "Show the building", bundle: .module)
        }
    }

    private static let defaultsKey = "officeViewStyle"

    /// The style chosen last time on this device. The floor plan until one is chosen.
    public static func saved(in defaults: UserDefaults = .standard) -> OfficeViewStyle {
        defaults.string(forKey: defaultsKey).flatMap(OfficeViewStyle.init(rawValue:)) ?? .flat
    }

    public func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
