import SpriteKit

extension SKColor {

    /// Creates a color from a hex value such as `0x2E2A35`.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// The office palette, shared with the design mockup.
enum OfficePalette {
    static let wall = SKColor(hex: 0x2E2A35)
    static let wallShadow = SKColor(hex: 0x15131A)
    static let hallway = SKColor(hex: 0xD8CFC0)
    static let hallwayLine = SKColor(hex: 0xC9BFAE)
    static let signText = SKColor(hex: 0xFFF7E6)
    static let signSubtitle = SKColor(hex: 0xE9C46A)

    static let wood = SKColor(hex: 0xC08A55)
    static let woodDark = SKColor(hex: 0x7A4E2A)
    static let chair = SKColor(hex: 0x8C3B4A)
    static let chairDark = SKColor(hex: 0x5E2532)
    static let screen = SKColor(hex: 0x1E2430)
    static let screenDark = SKColor(hex: 0x10131A)
    static let steel = SKColor(hex: 0x9AA3AD)
    static let steelDark = SKColor(hex: 0x5E6670)
    static let paper = SKColor(hex: 0xFBFBF7)
    static let leaf = SKColor(hex: 0x3E8E5E)
    static let leafDark = SKColor(hex: 0x255C3B)
    static let pot = SKColor(hex: 0xA8552E)

    static let red = SKColor(hex: 0xC0392B)
    static let blue = SKColor(hex: 0x2E86AB)
    static let yellow = SKColor(hex: 0xF2B33D)
    static let green = SKColor(hex: 0x5BE37D)
    static let sky = SKColor(hex: 0x7CC3E8)
}
