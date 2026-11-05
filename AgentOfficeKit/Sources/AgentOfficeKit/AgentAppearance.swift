/// How an agent looks. Picked from the agent's ID so the same agent always looks the same.
///
/// Team leaders (main sessions) wear a dark suit with a red tie.
/// Team members (subagents) wear their department's uniform.
public struct AgentAppearance: Equatable, Sendable {
    public let hair: UInt32
    public let shirt: UInt32
    /// Only team leaders wear a tie.
    public let tie: UInt32?

    static let hairColors: [UInt32] = [0x3B2A20, 0xC46A2B, 0x1F1C24, 0xE9C46A, 0x5A3A6B, 0x8C3B4A]
    static let suitColor: UInt32 = 0x2B2D42
    static let tieColor: UInt32 = 0xC0392B

    public init(id: String, role: TeamRole? = nil) {
        // Swift's hashValue changes on every launch, so use a fixed hash (FNV-1a) instead.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        hair = Self.hairColors[Int(hash % UInt64(Self.hairColors.count))]
        if let role {
            shirt = role.department.uniform
            tie = nil
        } else {
            shirt = Self.suitColor
            tie = Self.tieColor
        }
    }
}
