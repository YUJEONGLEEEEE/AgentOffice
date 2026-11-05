import SpriteKit

/// One agent character in the office: a pixel sprite, a status tag above its head and a name below.
final class AgentNode: SKNode {

    typealias Pose = AgentPortrait.Pose

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
    private let namePlate = SKSpriteNode()
    private var textures: [Pose: SKTexture] = [:]
    private var status: AgentStatus = .arrived
    private var pendingWalk: (() -> Void)?

    init(snapshot: AgentSnapshot) {
        agentID = snapshot.id
        appearance = AgentAppearance(id: snapshot.id, role: snapshot.role.map(TeamRole.init))
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
        namePlate.color = OfficePalette.wall.withAlphaComponent(0.8)
        namePlate.size = CGSize(width: nameLabel.frame.width + 8, height: 12)
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

    /// Neighbors in the same room alternate tag and name plate heights so they do not overlap.
    private func updateTagHeight() {
        let base = body.size.height + 14
        let isOdd = spotIndex % 2 == 1
        tag.position = CGPoint(x: 0, y: isOdd ? base + 22 : base)
        namePlate.position = CGPoint(x: 0, y: isOdd ? -16 : -2)
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
        let text = status == .resting && room == .breakRoom ? "쉬는 중 · 커피" : status.displayName
        return TagStyle(text: text, background: SKColor(hex: status.tagColor), foreground: SKColor(hex: status.tagTextColor))
    }

    private static func texture(for pose: Pose, appearance: AgentAppearance) -> SKTexture {
        guard let image = AgentPortrait.image(for: pose, appearance: appearance) else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}
