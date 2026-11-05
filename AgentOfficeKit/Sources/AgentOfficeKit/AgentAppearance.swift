/// How an agent looks. Picked from the agent's ID so the same agent always looks the same.
public struct AgentAppearance: Equatable, Sendable {
    public let hair: UInt32
    public let shirt: UInt32

    static let hairColors: [UInt32] = [0x3B2A20, 0xC46A2B, 0x1F1C24, 0xE9C46A, 0x5A3A6B, 0x8C3B4A]
    static let shirtColors: [UInt32] = [0x2F5E8C, 0xC0392B, 0x3E8E5E, 0x6F8FBF, 0xE9C46A, 0xD9822B, 0x7B5EA7]

    public init(id: String) {
        // Swift's hashValue changes on every launch, so use a fixed hash (FNV-1a) instead.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        hair = Self.hairColors[Int(hash % UInt64(Self.hairColors.count))]
        shirt = Self.shirtColors[Int((hash / 7) % UInt64(Self.shirtColors.count))]
    }
}
