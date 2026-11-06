import SpriteKit

/// The office building in cutaway: every project is a floor, and each floor shows its rooms
/// with the agents working in them. Picking a floor calls `onSelectFloor`.
public final class BuildingScene: SKScene {

    /// Called with the floor's name when the user clicks or taps a floor.
    public var onSelectFloor: ((String) -> Void)?

    public private(set) var layout = BuildingLayout(floors: [])
    private var floorSummaries: [FloorSummary] = []
    private let structure = SKNode()
    private let peopleLayer = SKNode()
    private var people: [String: SKSpriteNode] = [:]
    private var highlights: [String: SKNode] = [:]
    private var hoveredFloor: String?

    public override init() {
        super.init(size: layout.size)
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = SKColor(hex: 0xB6D2EA)
        addChild(structure)
        peopleLayer.zPosition = Layer.people
        addChild(peopleLayer)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Content

    /// Shows the floors and who is on them. Agents without a floor (team members waiting at their desks) are not shown.
    public func show(agents: [AgentSnapshot]) {
        let onFloors = agents.filter { !$0.floor.isEmpty && $0.status != .left }
        let summaries = FloorSummary.floors(from: agents.filter { !$0.floor.isEmpty })
        if summaries.map(\.name) != floorSummaries.map(\.name) || size != BuildingLayout(floors: summaries.map(\.name)).size {
            floorSummaries = summaries
            layout = BuildingLayout(floors: summaries.map(\.name))
            size = layout.size
            build()
        } else if summaries != floorSummaries {
            floorSummaries = summaries
            updateFloorLabels()
        }
        showPeople(onFloors)
    }

    // MARK: - Building

    private enum Layer {
        static let sky: CGFloat = 0
        static let shell: CGFloat = 1
        static let room: CGFloat = 2
        static let furniture: CGFloat = 3
        static let label: CGFloat = 5
        static let people: CGFloat = 10
        static let highlight: CGFloat = 20
    }

    private func build() {
        structure.removeAllChildren()
        highlights.removeAll()
        people.values.forEach { $0.removeFromParent() }
        people.removeAll()

        let width = layout.size.width, height = layout.size.height
        // Sky bands, ground and a pair of trees
        for (index, hex) in [0xD3E6F4, 0xC8DFF0, 0xBED8EC].enumerated() {
            box(CGRect(x: 0, y: CGFloat(index) * 14, width: width, height: 14), SKColor(hex: UInt32(hex)), z: Layer.sky)
        }
        box(CGRect(x: 0, y: height - 18, width: width, height: 18), SKColor(hex: 0x7AA86A), z: Layer.sky)

        let floors = layout.floorsTopDown
        guard let topFrame = floors.first.flatMap(layout.frame(ofFloor:)) else {
            drawLobby(top: height - BuildingLayout.lobbyHeight - 18)
            return
        }
        let shell = CGRect(x: topFrame.minX - 8, y: topFrame.minY - 14, width: topFrame.width + 16,
                           height: height - 18 - (topFrame.minY - 14))
        box(shell, SKColor(hex: 0x43475A), z: Layer.shell)
        // Roof sign
        let sign = CGRect(x: width / 2 - 110, y: topFrame.minY - 40, width: 220, height: 28)
        box(sign, SKColor(hex: 0x43475A), z: Layer.shell)
        box(sign.insetBy(dx: 4, dy: 4), OfficePalette.yellow, z: Layer.shell + 0.1)
        label("AgentOffice", at: CGPoint(x: sign.midX, y: sign.midY), size: 15, color: OfficePalette.wall, z: Layer.label)

        for floor in floors {
            drawFloor(floor)
        }
        // Floors too low for room names get one row of names above the top floor instead.
        if layout.floorHeight < 90 {
            for room in BuildingLayout.roomOrder {
                guard let roomFrame = floors.first.flatMap({ layout.frame(of: room, onFloor: $0) }) else { continue }
                label(room == .desk ? String(localized: "Workspace", bundle: .module) : room.displayName,
                      at: CGPoint(x: roomFrame.midX, y: topFrame.minY - 7), size: 10, color: SKColor(hex: 0xC8D0DE), z: Layer.label)
            }
        }
        drawLobby(top: height - 18 - BuildingLayout.lobbyHeight)
        updateFloorLabels()
    }

    private func drawFloor(_ floor: String) {
        guard let frame = layout.frame(ofFloor: floor) else { return }
        let labelColumn = CGRect(x: frame.minX, y: frame.minY, width: BuildingLayout.labelWidth - 4, height: frame.height - BuildingLayout.slabHeight)
        box(labelColumn, SKColor(hex: 0x2E3342), z: Layer.room)

        for room in BuildingLayout.roomOrder {
            guard let roomFrame = layout.frame(of: room, onFloor: floor) else { continue }
            let inner = roomFrame.insetBy(dx: 2, dy: 0)
            box(inner, Self.wallColor(room), z: Layer.room)
            box(CGRect(x: inner.minX, y: inner.maxY - 8, width: inner.width, height: 8), Self.floorColor(room), z: Layer.room + 0.1)
            furnish(room, in: inner)
            if frame.height >= 90 {
                label(room == .desk ? String(localized: "Workspace", bundle: .module) : room.displayName,
                      at: CGPoint(x: inner.midX, y: inner.minY + 12), size: 10,
                      color: room == .serverRoom ? OfficePalette.signText : SKColor(hex: 0x4A5060), z: Layer.label)
            }
        }
        box(CGRect(x: frame.minX, y: frame.maxY - BuildingLayout.slabHeight, width: frame.width, height: BuildingLayout.slabHeight),
            SKColor(hex: 0x5B6070), z: Layer.room)

        // Shown while the pointer is over the floor
        let highlight = SKNode()
        highlight.zPosition = Layer.highlight
        for edge in [CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 3),
                     CGRect(x: frame.minX, y: frame.maxY - 3, width: frame.width, height: 3),
                     CGRect(x: frame.minX, y: frame.minY, width: 3, height: frame.height),
                     CGRect(x: frame.maxX - 3, y: frame.minY, width: 3, height: frame.height)] {
            let line = SKSpriteNode(color: OfficePalette.yellow, size: edge.size)
            let sceneEdge = layout.sceneRect(edge)
            line.position = CGPoint(x: sceneEdge.midX, y: sceneEdge.midY)
            highlight.addChild(line)
        }
        highlight.isHidden = floor != hoveredFloor
        structure.addChild(highlight)
        highlights[floor] = highlight
    }

    /// A few pieces of furniture so each room is recognizable even when small.
    private func furnish(_ room: Room, in frame: CGRect) {
        let floorLine = frame.maxY - 8
        let scale = min(1, frame.height / 120)
        func piece(_ x: CGFloat, _ fromFloor: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: SKColor) {
            box(CGRect(x: frame.minX + x * frame.width, y: floorLine - fromFloor * scale, width: w * scale, height: h * scale), color, z: Layer.furniture)
        }
        switch room {
        case .meetingRoom:
            piece(0.12, 70, 60, 34, OfficePalette.paper)
            piece(0.18, 60, 30, 3, SKColor(hex: 0x2F5E8C)); piece(0.18, 52, 40, 3, OfficePalette.red)
            piece(0.5, 24, 54, 6, OfficePalette.wood)
        case .archive:
            piece(0.58, 92, 34, 92, OfficePalette.woodDark)
            for row in 0..<4 { piece(0.62, CGFloat(86 - row * 22), 24, 16, [OfficePalette.blue, OfficePalette.yellow, OfficePalette.leaf, OfficePalette.red][row]) }
        case .researchRoom:
            piece(0.2, 26, 70, 6, OfficePalette.wood)
            piece(0.3, 52, 30, 22, OfficePalette.screen); piece(0.33, 48, 22, 14, SKColor(hex: 0x6EC1F0))
        case .devRoom:
            for x in [0.1, 0.55] as [CGFloat] {
                piece(x, 26, 52, 6, OfficePalette.wood)
                piece(x + 0.08, 52, 28, 22, OfficePalette.screen); piece(x + 0.1, 46, 16, 3, OfficePalette.green)
            }
        case .desk:
            for x in [0.08, 0.38, 0.68] as [CGFloat] { piece(x, 26, 44, 6, OfficePalette.wood); piece(x + 0.06, 46, 22, 16, OfficePalette.screen) }
        case .serverRoom:
            for x in [0.15, 0.55] as [CGFloat] {
                piece(x, 96, 26, 96, OfficePalette.screenDark)
                for row in 0..<5 {
                    let light = SKSpriteNode(color: OfficePalette.green, size: CGSize(width: 4 * scale, height: 4 * scale))
                    let rect = CGRect(x: frame.minX + x * frame.width + 8 * scale, y: floorLine - CGFloat(88 - row * 18) * scale, width: 4 * scale, height: 4 * scale)
                    let sceneRect = layout.sceneRect(rect)
                    light.position = CGPoint(x: sceneRect.midX, y: sceneRect.midY)
                    light.zPosition = Layer.furniture + 0.1
                    light.run(.repeatForever(.sequence([.wait(forDuration: Double(row) * 0.3 + 0.4), .fadeAlpha(to: 0.3, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)])))
                    structure.addChild(light)
                }
            }
        case .breakRoom:
            piece(0.62, 64, 26, 64, OfficePalette.red); piece(0.65, 56, 16, 12, SKColor(hex: 0x6EC1F0))
            piece(0.1, 22, 60, 22, SKColor(hex: 0x2F5E8C))
        }
    }

    private func drawLobby(top: CGFloat) {
        let width = layout.size.width
        let lobby = CGRect(x: BuildingLayout.sideMargin - 8, y: top, width: width - (BuildingLayout.sideMargin - 8) * 2, height: BuildingLayout.lobbyHeight)
        box(lobby, SKColor(hex: 0x5B6070), z: Layer.shell)
        box(CGRect(x: width / 2 - 40, y: top + 6, width: 80, height: BuildingLayout.lobbyHeight - 6), SKColor(hex: 0xC9CED8), z: Layer.room)
        box(CGRect(x: width / 2 - 2, y: top + 6, width: 4, height: BuildingLayout.lobbyHeight - 6), SKColor(hex: 0x9AA3B0), z: Layer.room + 0.1)
    }

    private func updateFloorLabels() {
        structure.children.filter { $0.name == "floorLabel" }.forEach { $0.removeFromParent() }
        for summary in floorSummaries {
            guard let frame = layout.frame(ofFloor: summary.name), let level = layout.level(of: summary.name) else { continue }
            let x = frame.minX + (BuildingLayout.labelWidth - 4) / 2
            let compact = frame.height < 90
            let nodes = [
                label("\(level)F", at: CGPoint(x: x, y: frame.minY + (compact ? 16 : 26)), size: compact ? 16 : 22, color: OfficePalette.signText, z: Layer.label),
                label(Self.shortName(summary.name), at: CGPoint(x: x, y: frame.minY + (compact ? 34 : 52)), size: 11, color: SKColor(hex: 0xC8D0DE), z: Layer.label),
                label(summary.presentCount > 0 ? OfficeText.atWork(summary.presentCount) : OfficeText.emptyFloor,
                      at: CGPoint(x: x, y: frame.minY + (compact ? 48 : 70)), size: 10,
                      color: summary.presentCount > 0 ? OfficePalette.yellow : SKColor(hex: 0x8A93A6), z: Layer.label),
            ]
            nodes.forEach { $0.name = "floorLabel" }
        }
    }

    private static func shortName(_ name: String) -> String {
        name.count > 12 ? name.prefix(11) + "…" : name
    }

    // MARK: - People

    private func showPeople(_ agents: [AgentSnapshot]) {
        var counts: [String: Int] = [:]
        var seen: Set<String> = []
        let personHeight = min(48, layout.floorHeight * 0.42)
        for agent in agents.sorted(by: { $0.id < $1.id }) {
            let key = "\(agent.floor)|\(agent.room.rawValue)"
            let index = counts[key, default: 0]
            counts[key] = index + 1
            guard let spot = layout.spot(in: agent.room, onFloor: agent.floor, index: index) else { continue }
            seen.insert(agent.id)

            let node = people[agent.id] ?? makePerson(for: agent)
            people[agent.id] = node
            node.size = CGSize(width: personHeight * 0.75, height: personHeight)
            let feet = layout.scenePoint(spot)
            node.position = CGPoint(x: feet.x, y: feet.y + personHeight / 2)
            updateStatusDot(on: node, status: agent.status, personHeight: personHeight)
        }
        for (id, node) in people where !seen.contains(id) {
            node.removeFromParent()
            people[id] = nil
        }
    }

    private func makePerson(for agent: AgentSnapshot) -> SKSpriteNode {
        let texture = AgentPortrait.image(forAgentID: agent.id, role: agent.role).map(SKTexture.init(cgImage:)) ?? SKTexture()
        texture.filteringMode = .nearest
        let node = SKSpriteNode(texture: texture)
        let dot = SKSpriteNode(color: .clear, size: .zero)
        dot.name = "status"
        let border = SKSpriteNode(color: OfficePalette.wall, size: .zero)
        border.name = "statusBorder"
        border.zPosition = 0.1
        dot.zPosition = 0.2
        node.addChild(border)
        node.addChild(dot)
        peopleLayer.addChild(node)
        return node
    }

    private func updateStatusDot(on node: SKSpriteNode, status: AgentStatus, personHeight: CGFloat) {
        let side = max(6, personHeight * 0.2)
        let y = personHeight / 2 + side
        if let dot = node.childNode(withName: "status") as? SKSpriteNode {
            dot.color = SKColor(hex: status.tagColor)
            dot.size = CGSize(width: side, height: side)
            dot.position = CGPoint(x: 0, y: y)
        }
        if let border = node.childNode(withName: "statusBorder") as? SKSpriteNode {
            border.size = CGSize(width: side + 4, height: side + 4)
            border.position = CGPoint(x: 0, y: y)
        }
        // People who are working bob a little, so a busy floor looks busy.
        let isBusy = status == .working || status == .received
        if isBusy, node.action(forKey: "busy") == nil {
            node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.25), .moveBy(x: 0, y: -2, duration: 0.25)])), withKey: "busy")
        } else if !isBusy {
            node.removeAction(forKey: "busy")
        }
    }

    // MARK: - Picking a floor

    private func floor(atScenePoint point: CGPoint) -> String? {
        layout.floor(at: layout.layoutPoint(point))
    }

    private func setHovered(_ floor: String?) {
        guard floor != hoveredFloor else { return }
        hoveredFloor = floor
        for (name, node) in highlights {
            node.isHidden = name != floor
        }
    }

    #if os(macOS)
    public override func mouseMoved(with event: NSEvent) {
        let floor = floor(atScenePoint: event.location(in: self))
        setHovered(floor)
        (floor == nil ? NSCursor.arrow : NSCursor.pointingHand).set()
    }

    public override func mouseExited(with event: NSEvent) {
        setHovered(nil)
        NSCursor.arrow.set()
    }

    public override func mouseUp(with event: NSEvent) {
        if let floor = floor(atScenePoint: event.location(in: self)) {
            onSelectFloor?(floor)
        }
    }
    #else
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let floor = floor(atScenePoint: touch.location(in: self)) else { return }
        onSelectFloor?(floor)
    }
    #endif

    // MARK: - Drawing helpers

    @discardableResult
    private func box(_ frame: CGRect, _ color: SKColor, z: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(color: color, size: frame.size)
        let sceneFrame = layout.sceneRect(frame)
        node.position = CGPoint(x: sceneFrame.midX, y: sceneFrame.midY)
        node.zPosition = z
        structure.addChild(node)
        return node
    }

    @discardableResult
    private func label(_ text: String, at center: CGPoint, size: CGFloat, color: SKColor, z: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(text: text)
        node.fontName = "AppleSDGothicNeo-Bold"
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        node.position = layout.scenePoint(center)
        node.zPosition = z
        structure.addChild(node)
        return node
    }

    private static func wallColor(_ room: Room) -> SKColor {
        switch room {
        case .meetingRoom: SKColor(hex: 0xDFE6F2)
        case .archive: SKColor(hex: 0xEFE5D2)
        case .researchRoom: SKColor(hex: 0xDCEFED)
        case .devRoom: SKColor(hex: 0xE2EBE2)
        case .desk: SKColor(hex: 0xF0E8D8)
        case .serverRoom: SKColor(hex: 0x3A4150)
        case .breakRoom: SKColor(hex: 0xF1ECE2)
        }
    }

    private static func floorColor(_ room: Room) -> SKColor {
        switch room {
        case .meetingRoom: SKColor(hex: 0x7F8FB0)
        case .archive: SKColor(hex: 0xB98A5A)
        case .researchRoom: SKColor(hex: 0x7FB7B2)
        case .devRoom: SKColor(hex: 0x8A9A7C)
        case .desk: SKColor(hex: 0xCDBA96)
        case .serverRoom: SKColor(hex: 0x2C3140)
        case .breakRoom: SKColor(hex: 0xD6CCB8)
        }
    }
}
