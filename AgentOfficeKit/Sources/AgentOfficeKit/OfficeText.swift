import Foundation

/// Words that both apps show, translated in the package's string catalog.
public enum OfficeText {

    /// The whole office, every floor together.
    public static var allFloors: String { String(localized: "All", bundle: .module) }

    /// Where an agent who went home is.
    public static var outOfOffice: String { String(localized: "Out of office", bundle: .module) }

    /// A time a few seconds ago. It is shown in the middle of a line, like "Archive · just now".
    public static var justNow: String { String(localized: "just now", bundle: .module) }

    /// A floor with nobody working on it.
    public static var emptyFloor: String { String(localized: "Empty", bundle: .module) }

    /// The office scene, for VoiceOver.
    public static var office: String { String(localized: "Office", bundle: .module) }

    /// How many people are working, for example "3 at work".
    public static func atWork(_ count: Int) -> String {
        String(localized: "\(count) at work", bundle: .module)
    }
}
