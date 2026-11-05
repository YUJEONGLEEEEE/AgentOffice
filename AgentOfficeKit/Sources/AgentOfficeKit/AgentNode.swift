import SpriteKit

/// One agent character in the office: a pixel sprite, a status tag above its head and a name below.
final class AgentNode: SKNode {

    enum Pose {
        case stand, walkA, walkB, raisedHand
    }

    private static let pixelScale: CGFloat = 3
    private static let walkSpeed: CGFloat = 140

    let agentID: String
    /// The room the agent is in, or heading to. `nil` means the elevator.
    private(set) var room: Room?
    private(set) var spotIndex = 0
    private(set) var isWalking = false

    private let appearance: AgentAppearance
    private let body = SKSpriteNode()
    private let cup = SKSpriteNode(color: OfficePalette.paper, size: CGSize(width: 6, height: 6))
    private let tag = SKNode()
    private let tagPlate = SKSpriteNode()
    private let tagBorder = SKSpriteNode()
    private let tagLabel = SKLabelNode()
    private let nameLabel = SKLabelNode()
    private var textures: [Pose: SKTexture] = [:]
    private var status: AgentStatus = .arrived
    private var pendingWalk: (() -> Void)?

    init(snapshot: AgentSnapshot) {
        agentID = snapshot.id
        appearance = AgentAppearance(id: snapshot.id)
        super.init()

        for pose in [Pose.stand, .walkA, .walkB, .raisedHand] {
            textures[pose] = Self.texture(for: pose, appearance: appearance)
        }

        let shadow = SKSpriteNode(color: SKColor(white: 0, alpha: 0.2), size: CGSize(width: 30, height: 6))
        shadow.position = CGPoint(x: 0, y: 1)
        addChild(shadow)

        body.texture = textures[.stand]
        body.size = CGSize(width: 12 * Self.pixelScale, height: 16 * Self.pixelScale)
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.zPosition = 1
        addChild(body)

        cup.position = CGPoint(x: 15, y: 16)
        cup.zPosition = 2
        cup.isHidden = true
        addChild(cup)

        tagLabel.fontName = "AppleSDGothicNeo-Heavy"
        tagLabel.fontSize = 11
        tagLabel.verticalAlignmentMode = .center
        tagLabel.horizontalAlignmentMode = .center
        tagBorder.color = OfficePalette.wall
        tag.addChild(tagBorder)
        tag.addChild(tagPlate)
        tag.addChild(tagLabel)
        tagPlate.zPosition = 0.1
        tagLabel.zPosition = 0.2
        tag.position = CGPoint(x: 0, y: body.size.height + 14)
        tag.zPosition = 5
        addChild(tag)

        nameLabel.text = snapshot.name
        nameLabel.fontName = "Menlo-Bold"
        nameLabel.fontSize = 9
        nameLabel.fontColor = OfficePalette.signText
        nameLabel.verticalAlignmentMode = .top
        let namePlate = SKSpriteNode(color: OfficePalette.wall.withAlphaComponent(0.8),
                                     size: CGSize(width: nameLabel.frame.width + 8, height: 12))
        namePlate.anchorPoint = CGPoint(x: 0.5, y: 1)
        namePlate.position = CGPoint(x: 0, y: -2)
        namePlate.zPosition = 5
        nameLabel.position = CGPoint(x: 0, y: -1)
        nameLabel.zPosition = 0.1
        namePlate.addChild(nameLabel)
        addChild(namePlate)

        apply(snapshot)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - State

    /// Updates the tag and pose for the latest status.
    func apply(_ snapshot: AgentSnapshot) {
        status = snapshot.status
        let style = Self.tagStyle(for: snapshot.status, room: snapshot.room)
        tagLabel.text = style.text
        tagLabel.fontColor = style.foreground
        let size = CGSize(width: tagLabel.frame.width + 14, height: 18)
        tagPlate.color = style.background
        tagPlate.size = size
        tagBorder.size = CGSize(width: size.width + 4, height: size.height + 4)
        if !isWalking {
            showRestingPose()
        }
    }

    /// Walks along the route to a new room. A new walk that arrives mid-walk waits for the current one,
    /// so agents never cut through walls.
    func walk(to destination: Room?, index: Int, layout: OfficeLayout, completion: (() -> Void)? = nil) {
        let start = room
        let startIndex = spotIndex
        room = destination
        spotIndex = index

        let begin = { [weak self] in
            guard let self else { return }
            let points = layout.path(from: start, startIndex: startIndex, to: destination, endIndex: index)
                .map(layout.scenePoint)
            self.followPath(points, completion: completion)
        }

        if isWalking {
            pendingWalk = begin
        } else {
            begin()
        }
    }

    /// Places the agent without walking, for example when the office first appears.
    func place(in destination: Room?, index: Int, layout: OfficeLayout) {
        room = destination
        spotIndex = index
        let point = destination.map { layout.spot(for: $0, index: index) } ?? layout.elevatorSpot
        position = layout.scenePoint(point)
        updateDepth()
        updateTagHeight()
    }

    // MARK: - Movement

    private func followPath(_ points: [CGPoint], completion: (() -> Void)?) {
        isWalking = true
        cup.isHidden = true

        var steps: [SKAction] = []
        var current = position
        for point in points {
            let distance = hypot(point.x - current.x, point.y - current.y)
            guard distance > 0.5 else { continue }
            let facesLeft = point.x < current.x - 0.5
            let facesRight = point.x > current.x + 0.5
            steps.append(.run { [weak self] in
                if facesLeft { self?.body.xScale = -1 }
                if facesRight { self?.body.xScale = 1 }
            })
            let move = SKAction.move(to: point, duration: TimeInterval(distance / Self.walkSpeed))
            steps.append(.group([move, .customAction(withDuration: move.duration) { [weak self] _, _ in self?.updateDepth() }]))
            current = point
        }

        let legs = SKAction.repeatForever(.animate(with: [textures[.walkA]!, textures[.walkB]!], timePerFrame: 0.14))
        body.run(legs, withKey: "legs")

        steps.append(.run { [weak self] in
            guard let self else { return }
            self.body.removeAction(forKey: "legs")
            self.isWalking = false
            self.showRestingPose()
            completion?()
            if let next = self.pendingWalk {
                self.pendingWalk = nil
                next()
            }
        })
        run(.sequence(steps), withKey: "walk")
    }

    /// Neighbors in the same room alternate tag heights so their tags do not overlap.
    private func updateTagHeight() {
        let base = body.size.height + 14
        tag.position = CGPoint(x: 0, y: spotIndex % 2 == 1 ? base + 22 : base)
    }

    private func showRestingPose() {
        updateTagHeight()
        body.texture = status == .waiting ? textures[.raisedHand] : textures[.stand]
        cup.isHidden = !(status == .resting && room == .breakRoom)
        if status == .waiting {
            body.xScale = 1
        }
    }

    /// Agents lower on the screen are drawn in front of agents higher up.
    private func updateDepth() {
        zPosition = 20 + (1000 - position.y) / 1000
    }

    // MARK: - Look

    private struct TagStyle {
        let text: String
        let background: SKColor
        let foreground: SKColor
    }

    private static func tagStyle(for status: AgentStatus, room: Room) -> TagStyle {
        switch status {
        case .working:
            TagStyle(text: "일하는 중", background: SKColor(hex: 0xF2B33D), foreground: SKColor(hex: 0x2E2A35))
        case .waiting:
            TagStyle(text: "기다리는 중", background: SKColor(hex: 0xE8684A), foreground: SKColor(hex: 0x1F1C24))
        case .resting:
            TagStyle(text: room == .breakRoom ? "쉬는 중 · 커피" : "쉬는 중",
                     background: SKColor(hex: 0xBFE3C8), foreground: SKColor(hex: 0x1F3A28))
        case .arrived, .received:
            TagStyle(text: status.displayName, background: SKColor(hex: 0xBFD7F5), foreground: SKColor(hex: 0x1E3350))
        case .left:
            TagStyle(text: status.displayName, background: SKColor(hex: 0xC9C0B0), foreground: SKColor(hex: 0x2E2A35))
        }
    }

    /// 12 × 16 pixel maps. h hair, s skin, e eye, m mouth, t shirt, p pants, b shoes.
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

    private static func texture(for pose: Pose, appearance: AgentAppearance) -> SKTexture {
        let rows = map(for: pose)
        let width = 12, height = 16
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        let colors: [Character: UInt32] = [
            "h": appearance.hair, "s": 0xF2C9A0, "e": 0x2B2B2B, "m": 0xD98A6A,
            "t": appearance.shirt, "p": 0x3A3F58, "b": 0x1F1C24,
        ]
        for (rowIndex, row) in rows.enumerated() {
            for (column, character) in row.enumerated() {
                guard let hex = colors[character] else { continue }
                context.setFillColor(SKColor(hex: hex).cgColor)
                // CoreGraphics draws from the bottom, so flip the row.
                context.fill(CGRect(x: column, y: height - 1 - rowIndex, width: 1, height: 1))
            }
        }
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}
