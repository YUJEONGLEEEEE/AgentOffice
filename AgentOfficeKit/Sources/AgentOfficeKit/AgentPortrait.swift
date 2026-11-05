import CoreGraphics

/// The agent's pixel character as an image. The office scene and the app's cards both draw from here.
public enum AgentPortrait {

    enum Pose {
        case stand, walkA, walkB, raisedHand
    }

    /// A 12 × 16 pixel image. Draw it with nearest-neighbor scaling to keep the pixels sharp.
    /// `role` is the team member's agent type, or `nil` for a team leader.
    public static func image(forAgentID id: String, role: String? = nil) -> CGImage? {
        image(for: .stand, appearance: AgentAppearance(id: id, role: role.map(TeamRole.init)))
    }

    /// 12 × 16 pixel maps. h hair, s skin, e eye, m mouth, t shirt, p pants, b shoes, k tie.
    private static let standMap = [
        "...hhhhhh...",
        "..hhhhhhhh..",
        "..hhhhhhhh..",
        "..hssssssh..",
        "..hsessesh..",
        "...ssssss...",
        "...ssmmss...",
        "..tttttttt..",
        ".tttttttttt.",
        ".tttttttttt.",
        ".tttttttttt.",
        ".stttttttts.",
        "...pppppp...",
        "...pp..pp...",
        "...pp..pp...",
        "...bb..bb...",
    ]

    private static func map(for pose: Pose) -> [String] {
        var rows = standMap.map { Array($0) }
        switch pose {
        case .stand:
            break
        case .walkA:
            rows[14] = Array("..pp...pp...")
            rows[15] = Array("..bb....bb..")
        case .walkB:
            rows[14] = Array("....pp..pp..")
            rows[15] = Array("....bb...bb.")
        case .raisedHand:
            for row in 8...11 { rows[row][10] = "." }
            for row in 4...7 { rows[row][10] = "t" }
            rows[3][10] = "s"
        }
        return rows.map { String($0) }
    }

    /// The 12 × 16 pixel picture of the agent in a pose.
    static func image(for pose: Pose, appearance: AgentAppearance) -> CGImage? {
        var rows = map(for: pose)
        if appearance.tie != nil {
            // A tie down the middle of the shirt.
            for row in 7...10 {
                var pixels = Array(rows[row])
                pixels[5] = "k"
                pixels[6] = "k"
                rows[row] = String(pixels)
            }
        }
        let width = 12, height = 16
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let colors: [Character: UInt32] = [
            "h": appearance.hair, "s": 0xF2C9A0, "e": 0x2B2B2B, "m": 0xD98A6A,
            "t": appearance.shirt, "p": 0x3A3F58, "b": 0x1F1C24,
            "k": appearance.tie ?? appearance.shirt,
        ]
        for (rowIndex, row) in rows.enumerated() {
            for (column, character) in row.enumerated() {
                guard let hex = colors[character] else { continue }
                context.setFillColor(CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1))
                // CoreGraphics draws from the bottom, so flip the row.
                context.fill(CGRect(x: column, y: height - 1 - rowIndex, width: 1, height: 1))
            }
        }
        return context.makeImage()
    }
}
