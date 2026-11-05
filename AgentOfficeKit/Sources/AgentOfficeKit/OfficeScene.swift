import SpriteKit

/// A top-down pixel-art office floor drawn with SpriteKit.
///
/// The scene only draws the static office for now: floors, walls, doors, furniture and room signs.
/// Positions come from `OfficeLayout`, so the same scene works on macOS and iOS.
public final class OfficeScene: SKScene {

    public let layout: OfficeLayout

    private var isBuilt = false
    private var agentNodes: [String: AgentNode] = [:]
    private var pendingSnapshots: [AgentSnapshot]?
    private var hasShownAgents = false

    public init(layout: OfficeLayout = .standard) {
        self.layout = layout
        super.init(size: layout.size)
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = OfficePalette.wall
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        guard !isBuilt else { return }
        isBuilt = true
        buildOffice()
        if let pendingSnapshots {
            self.pendingSnapshots = nil
            show(agents: pendingSnapshots)
        }
    }

    // MARK: - Agents

    /// Shows the agents on this floor. New agents step out of the elevator, agents whose room changed
    /// walk there through the hallway, and agents who left walk back to the elevator.
    ///
    /// The first call places everyone right away, so opening the app does not start a parade.
    public func show(agents snapshots: [AgentSnapshot]) {
        guard isBuilt else {
            pendingSnapshots = snapshots
            return
        }

        let present = snapshots.filter { $0.status != .left }
        var spotIndices: [String: Int] = [:]
        for room in Room.allCases {
            let ids = present.filter { $0.room == room }.map(\.id).sorted()
            for (index, id) in ids.enumerated() {
                spotIndices[id] = index
            }
        }

        let animate = hasShownAgents
        hasShownAgents = true

        for snapshot in present {
            let index = spotIndices[snapshot.id] ?? 0
            if let node = agentNodes[snapshot.id] {
                node.apply(snapshot)
                if node.room != snapshot.room || node.spotIndex != index {
                    node.walk(to: snapshot.room, index: index, layout: layout)
                }
            } else {
                let node = AgentNode(snapshot: snapshot)
                agentNodes[snapshot.id] = node
                addChild(node)
                if animate {
                    node.place(in: nil, index: 0, layout: layout)
                    node.walk(to: snapshot.room, index: index, layout: layout)
                } else {
                    node.place(in: snapshot.room, index: index, layout: layout)
                }
            }
        }

        let presentIDs = Set(present.map(\.id))
        for (id, node) in agentNodes where !presentIDs.contains(id) {
            agentNodes[id] = nil
            node.walk(to: nil, index: 0, layout: layout) { [weak node] in
                node?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            }
        }
    }

    // MARK: - Building

    private func buildOffice() {
        drawHallway()
        for room in Room.allCases {
            drawRoom(room)
        }
        for door in layout.doors {
            box(door, OfficePalette.hallway, z: Layer.door)
        }
        furnishHallway()
        furnishMeetingRoom()
        furnishArchive()
        furnishResearchRoom()
        furnishDevRoom()
        furnishDesks()
        furnishServerRoom()
        furnishBreakRoom()
    }

    private enum Layer {
        static let floor: CGFloat = 0
        static let wall: CGFloat = 1
        static let door: CGFloat = 2
        static let furniture: CGFloat = 3
        static let detail: CGFloat = 4
        static let sign: CGFloat = 10
    }

    private struct FloorStyle {
        let base: UInt32
        let line: UInt32
        let tile: Int
        var checker = false
        var planks = false
    }

    private func floorStyle(for room: Room) -> FloorStyle {
        switch room {
        case .meetingRoom: FloorStyle(base: 0x6F8FBF, line: 0x5E7FAF, tile: 28)
        case .archive: FloorStyle(base: 0xC99A63, line: 0xB88752, tile: 24, planks: true)
        case .researchRoom: FloorStyle(base: 0x7FB7B2, line: 0x6CA49F, tile: 32)
        case .devRoom: FloorStyle(base: 0x8FA38E, line: 0x7E937D, tile: 30)
        case .desk: FloorStyle(base: 0xCDBA96, line: 0xBFAB85, tile: 26)
        case .serverRoom: FloorStyle(base: 0x3A4150, line: 0x4A5263, tile: 24)
        case .breakRoom: FloorStyle(base: 0xE9E2D3, line: 0xD6CCB8, tile: 16, checker: true)
        }
    }

    private func signText(for room: Room) -> (title: String, subtitle: String) {
        switch room {
        case .meetingRoom: ("회의실", "PLAN · TODO · AGENT")
        case .archive: ("자료실", "READ · GREP · GLOB")
        case .researchRoom: ("정보검색실", "WEB SEARCH · FETCH")
        case .devRoom: ("개발실", "EDIT · WRITE")
        case .desk: ("업무 공간", "MY DESK · NEW TASK")
        case .serverRoom: ("서버실", "BASH · GIT")
        case .breakRoom: ("탕비실", "BREAK · COFFEE")
        }
    }

    private func drawHallway() {
        let style = FloorStyle(base: 0xD8CFC0, line: 0xC9BFAE, tile: 40)
        let node = SKSpriteNode(texture: floorTexture(size: layout.hallway.size, style: style, verticalOnly: true))
        place(node, in: layout.hallway, z: Layer.floor)
    }

    private func drawRoom(_ room: Room) {
        let frame = layout.frame(for: room)
        box(frame, OfficePalette.wall, z: Layer.wall)

        let interior = layout.interior(for: room)
        let floor = SKSpriteNode(texture: floorTexture(size: interior.size, style: floorStyle(for: room)))
        place(floor, in: interior, z: Layer.wall + 0.5)

        let text = signText(for: room)
        drawSign(title: text.title, subtitle: text.subtitle, at: CGPoint(x: interior.minX + 6, y: interior.minY + 4))
    }

    private func drawSign(title: String, subtitle: String, at topLeft: CGPoint) {
        let titleLabel = SKLabelNode(text: title)
        titleLabel.fontName = "AppleSDGothicNeo-Heavy"
        titleLabel.fontSize = 13
        titleLabel.fontColor = OfficePalette.signText

        let subtitleLabel = SKLabelNode(text: subtitle)
        subtitleLabel.fontName = "Menlo-Bold"
        subtitleLabel.fontSize = 8
        subtitleLabel.fontColor = OfficePalette.signSubtitle

        let width = max(titleLabel.frame.width, subtitleLabel.frame.width) + 16
        let plate = CGRect(x: topLeft.x, y: topLeft.y, width: width, height: 34)
        box(plate.offsetBy(dx: 0, dy: 3), OfficePalette.wallShadow.withAlphaComponent(0.4), z: Layer.sign - 0.2)
        box(plate, OfficePalette.wall, z: Layer.sign - 0.1)

        for label in [titleLabel, subtitleLabel] {
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .baseline
            label.zPosition = Layer.sign
        }
        titleLabel.position = layout.scenePoint(CGPoint(x: plate.minX + 8, y: plate.minY + 17))
        subtitleLabel.position = layout.scenePoint(CGPoint(x: plate.minX + 8, y: plate.minY + 29))
        addChild(titleLabel)
        addChild(subtitleLabel)
    }

    // MARK: - Furniture

    private func furnishHallway() {
        // Elevator
        box(CGRect(x: 8, y: 258, width: 72, height: 50), OfficePalette.steel, border: OfficePalette.steelDark)
        box(CGRect(x: 42, y: 261, width: 4, height: 44), OfficePalette.steelDark, z: Layer.detail)
        // Card reader: the hook that records every visit
        box(CGRect(x: 88, y: 270, width: 12, height: 20), OfficePalette.wall, border: OfficePalette.wallShadow)
        blink(box(CGRect(x: 92, y: 274, width: 4, height: 4), OfficePalette.green, z: Layer.detail), minimum: 0.4)

        plant(at: CGPoint(x: 300, y: 262))
        plant(at: CGPoint(x: 1110, y: 262))
        // Water cooler
        box(CGRect(x: 690, y: 260, width: 20, height: 42), SKColor(hex: 0xE8EEF2), border: OfficePalette.steel)
        box(CGRect(x: 693, y: 263, width: 14, height: 12), OfficePalette.sky, z: Layer.detail)
    }

    private func furnishMeetingRoom() {
        let o = layout.frame(for: .meetingRoom).origin
        // Whiteboard
        box(rect(o, 130, 8, 150, 40), OfficePalette.paper, border: OfficePalette.steel, borderWidth: 3)
        box(rect(o, 142, 18, 60, 3), SKColor(hex: 0x2F5E8C), z: Layer.detail)
        box(rect(o, 142, 26, 90, 3), OfficePalette.red, z: Layer.detail)
        box(rect(o, 142, 34, 44, 3), OfficePalette.leaf, z: Layer.detail)
        // Table and chairs
        desk(rect(o, 70, 112, 190, 64), color: SKColor(hex: 0xB9804A))
        for x in stride(from: 86, through: 212, by: 42) {
            chair(rect(o, CGFloat(x), 94, 20, 14))
            chair(rect(o, CGFloat(x), 180, 20, 14))
        }
        box(rect(o, 112, 128, 26, 18), OfficePalette.paper, z: Layer.detail)
        plant(at: CGPoint(x: o.x + 296, y: o.y + 190))
    }

    private func furnishArchive() {
        let o = layout.frame(for: .archive).origin
        let bookColors: [SKColor] = [OfficePalette.red, OfficePalette.blue, OfficePalette.yellow, OfficePalette.leaf, OfficePalette.paper]
        for (index, x) in [136, 202, 268, 334].enumerated() {
            let shelf = rect(o, CGFloat(x), 8, 60, 50)
            box(shelf, SKColor(hex: 0x6B4226), border: SKColor(hex: 0x4A2C17), borderWidth: 3)
            for row in 0..<2 {
                var bookX = shelf.minX + 6
                var colorIndex = index + row
                while bookX < shelf.maxX - 8 {
                    let width = CGFloat(4 + (colorIndex % 3))
                    box(CGRect(x: bookX, y: shelf.minY + 6 + CGFloat(row) * 20, width: width, height: 16),
                        bookColors[colorIndex % bookColors.count], z: Layer.detail)
                    bookX += width + 1
                    colorIndex += 1
                }
            }
        }
        // Filing cabinet
        box(rect(o, 352, 96, 34, 92), OfficePalette.steel, border: OfficePalette.steelDark, borderWidth: 3)
        for y in [110, 140, 170] {
            box(rect(o, 358, CGFloat(y), 16, 3), OfficePalette.steelDark, z: Layer.detail)
        }
        // Reading table with papers and a lamp
        desk(rect(o, 70, 150, 150, 56), color: SKColor(hex: 0x8C5A32))
        box(rect(o, 86, 160, 30, 22), OfficePalette.paper, z: Layer.detail)
        box(rect(o, 124, 164, 26, 18), SKColor(hex: 0xF4EEE2), z: Layer.detail)
        box(rect(o, 190, 156, 14, 10), OfficePalette.yellow, z: Layer.detail)
        chair(rect(o, 100, 210, 20, 14))
        chair(rect(o, 160, 210, 20, 14))
    }

    private func furnishResearchRoom() {
        let o = layout.frame(for: .researchRoom).origin
        let land = SKColor(hex: 0x8BC48A)
        // World map
        box(rect(o, 150, 8, 180, 48), OfficePalette.blue, border: SKColor(hex: 0x1D5A75), borderWidth: 3)
        for piece in [(168, 18, 34, 22), (212, 16, 22, 14), (222, 32, 16, 16), (262, 18, 44, 20), (290, 40, 14, 8)] {
            box(rect(o, CGFloat(piece.0), CGFloat(piece.1), CGFloat(piece.2), CGFloat(piece.3)), land, z: Layer.detail)
        }
        // Globe
        let globe = SKShapeNode(circleOfRadius: 20)
        globe.fillColor = OfficePalette.blue
        globe.strokeColor = SKColor(hex: 0x1D5A75)
        globe.lineWidth = 3
        globe.position = layout.scenePoint(CGPoint(x: o.x + 370, y: o.y + 104))
        globe.zPosition = Layer.furniture
        addChild(globe)
        box(rect(o, 358, 92, 14, 12), land, z: Layer.detail)
        box(rect(o, 366, 124, 8, 22), OfficePalette.woodDark)
        // Search desks
        for x in [30, 146, 262] {
            desk(rect(o, CGFloat(x), 150, 96, 42))
            monitor(rect(o, CGFloat(x + 24), 140, 46, 26), screen: SKColor(hex: 0x3BA7D9))
            chair(rect(o, CGFloat(x + 38), 198, 20, 14))
        }
    }

    private func furnishDevRoom() {
        let o = layout.frame(for: .devRoom).origin
        let codeColors: [SKColor] = [OfficePalette.green, OfficePalette.signSubtitle, OfficePalette.sky]
        for (row, y) in [70, 200].enumerated() {
            for (column, x) in [30, 170, 310].enumerated() {
                desk(rect(o, CGFloat(x), CGFloat(y), 120, 46))
                for screen in 0..<2 {
                    let frame = rect(o, CGFloat(x + 12 + screen * 52), CGFloat(y - 12), 46, 28)
                    monitor(frame, screen: OfficePalette.screen)
                    let color = codeColors[(row + column + screen) % codeColors.count]
                    for line in 0..<3 {
                        let width = CGFloat(10 + ((row + column + line + screen) % 3) * 8)
                        box(CGRect(x: frame.minX + 6, y: frame.minY + 6 + CGFloat(line) * 6, width: width, height: 2), color, z: Layer.detail + 0.1)
                    }
                }
                chair(rect(o, CGFloat(x + 50), CGFloat(y + 52), 20, 14))
            }
        }
    }

    private func furnishDesks() {
        let o = layout.frame(for: .desk).origin
        let mugColors: [SKColor] = [OfficePalette.red, OfficePalette.blue, OfficePalette.leaf, OfficePalette.yellow]
        for (index, position) in [(30, 74), (172, 74), (30, 200), (172, 200)].enumerated() {
            let x = CGFloat(position.0), y = CGFloat(position.1)
            desk(rect(o, x, y, 112, 50), color: SKColor(hex: 0xD9A066))
            monitor(rect(o, x + 34, y - 12, 44, 28), screen: SKColor(hex: 0x3A4150))
            box(rect(o, x + 10, y + 22, 10, 12), OfficePalette.paper, border: mugColors[index], borderWidth: 2, z: Layer.detail)
            if index % 2 == 0 {
                box(rect(o, x + 88, y + 14, 14, 20), OfficePalette.leaf, border: OfficePalette.leafDark, borderWidth: 2, z: Layer.detail)
            }
            chair(rect(o, x + 46, y + 56, 20, 14))
        }
    }

    private func furnishServerRoom() {
        let o = layout.frame(for: .serverRoom).origin
        // Air conditioner
        box(rect(o, 108, 8, 58, 18), SKColor(hex: 0xE8EEF2), border: OfficePalette.steel, borderWidth: 2)
        // Racks with blinking lights
        let lightColors: [SKColor] = [OfficePalette.green, OfficePalette.yellow, OfficePalette.sky, SKColor(hex: 0xE8684A)]
        for (rackIndex, x) in [18, 70, 122].enumerated() {
            let rack = rect(o, CGFloat(x), 70, 40, 130)
            box(rack, SKColor(hex: 0x23272F), border: OfficePalette.screenDark, borderWidth: 3)
            for row in 0..<10 {
                for column in 0..<2 {
                    let color = column == 0 ? OfficePalette.green : lightColors[(rackIndex + row) % lightColors.count]
                    let light = box(CGRect(x: rack.minX + 8 + CGFloat(column) * 14, y: rack.minY + 8 + CGFloat(row) * 12, width: 4, height: 3),
                                    color, z: Layer.detail)
                    if (row + column + rackIndex) % 3 == 0 {
                        blink(light, minimum: 0.2)
                    }
                }
            }
        }
        box(rect(o, 18, 206, 144, 6), OfficePalette.signSubtitle, z: Layer.detail)
    }

    private func furnishBreakRoom() {
        let o = layout.frame(for: .breakRoom).origin
        // Fridge and coffee machine
        box(rect(o, 112, 8, 30, 44), SKColor(hex: 0xE8EEF2), border: OfficePalette.steel, borderWidth: 3)
        box(rect(o, 150, 8, 30, 30), OfficePalette.wall, border: OfficePalette.wallShadow, borderWidth: 3)
        box(rect(o, 158, 14, 14, 8), SKColor(hex: 0xE8684A), z: Layer.detail)
        // Vending machine
        box(rect(o, 140, 70, 36, 64), OfficePalette.red, border: SKColor(hex: 0x7E2219), borderWidth: 3)
        for row in 0..<4 {
            box(rect(o, 146, CGFloat(78 + row * 7), 22, 5), row % 2 == 0 ? OfficePalette.sky : OfficePalette.yellow, z: Layer.detail)
        }
        // Round table with a coffee cup
        let table = SKShapeNode(circleOfRadius: 26)
        table.fillColor = OfficePalette.wood
        table.strokeColor = OfficePalette.woodDark
        table.lineWidth = 3
        table.position = layout.scenePoint(CGPoint(x: o.x + 66, y: o.y + 176))
        table.zPosition = Layer.furniture
        addChild(table)
        box(rect(o, 72, 150, 10, 10), OfficePalette.paper, border: OfficePalette.woodDark, borderWidth: 2, z: Layer.detail)
        steam(at: CGPoint(x: o.x + 77, y: o.y + 146))
        // Sofa
        box(rect(o, 20, 252, 120, 40), SKColor(hex: 0x2F5E8C), border: SKColor(hex: 0x1E4166), borderWidth: 3)
        box(rect(o, 23, 277, 114, 12), SKColor(hex: 0x24496E), z: Layer.detail)
        plant(at: CGPoint(x: o.x + 156, y: o.y + 246))
    }

    // MARK: - Pieces

    private func desk(_ frame: CGRect, color: SKColor = OfficePalette.wood) {
        box(frame.offsetBy(dx: 0, dy: 4), OfficePalette.wallShadow.withAlphaComponent(0.2), z: Layer.furniture - 0.1)
        box(frame, color, border: OfficePalette.woodDark, borderWidth: 3)
    }

    private func chair(_ frame: CGRect) {
        box(frame, OfficePalette.chair, border: OfficePalette.chairDark, borderWidth: 2)
    }

    private func monitor(_ frame: CGRect, screen: SKColor) {
        box(frame, screen, border: OfficePalette.screenDark, borderWidth: 2, z: Layer.detail)
    }

    private func plant(at topLeft: CGPoint) {
        box(CGRect(x: topLeft.x + 2, y: topLeft.y, width: 20, height: 30), OfficePalette.leaf, border: OfficePalette.leafDark, borderWidth: 2)
        box(CGRect(x: topLeft.x + 5, y: topLeft.y + 30, width: 14, height: 12), OfficePalette.pot)
    }

    private func steam(at bottom: CGPoint) {
        for (index, offset) in [CGFloat(-3), 2].enumerated() {
            let puff = box(CGRect(x: bottom.x + offset, y: bottom.y - 8, width: 2, height: 6), SKColor(white: 1, alpha: 0.7), z: Layer.detail)
            let rise = SKAction.sequence([
                .group([.moveBy(x: 0, y: 6, duration: 1.2), .fadeOut(withDuration: 1.2)]),
                .moveBy(x: 0, y: -6, duration: 0),
                .fadeAlpha(to: 0.7, duration: 0),
            ])
            puff.run(.sequence([.wait(forDuration: Double(index) * 0.6), .repeatForever(rise)]))
        }
    }

    private func blink(_ node: SKNode, minimum: CGFloat) {
        let duration = Double.random(in: 0.4...1.2)
        node.run(.repeatForever(.sequence([
            .fadeAlpha(to: minimum, duration: duration),
            .fadeAlpha(to: 1, duration: duration),
        ])))
    }

    // MARK: - Drawing helpers

    /// A rect relative to a room origin, in top-left coordinates.
    private func rect(_ origin: CGPoint, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: origin.x + x, y: origin.y + y, width: width, height: height)
    }

    /// Draws a solid rectangle, optionally with a border, from a top-left based frame.
    @discardableResult
    private func box(
        _ frame: CGRect,
        _ color: SKColor,
        border: SKColor? = nil,
        borderWidth: CGFloat = 2,
        z: CGFloat = Layer.furniture
    ) -> SKSpriteNode {
        if let border {
            let outer = SKSpriteNode(color: border, size: frame.size)
            place(outer, in: frame, z: z)
            let inner = SKSpriteNode(color: color, size: frame.insetBy(dx: borderWidth, dy: borderWidth).size)
            inner.zPosition = 0.01
            outer.addChild(inner)
            return outer
        }
        let node = SKSpriteNode(color: color, size: frame.size)
        place(node, in: frame, z: z)
        return node
    }

    private func place(_ node: SKSpriteNode, in frame: CGRect, z: CGFloat) {
        let sceneFrame = layout.sceneRect(frame)
        node.position = CGPoint(x: sceneFrame.midX, y: sceneFrame.midY)
        node.zPosition = z
        addChild(node)
    }

    /// Draws a tiled floor into a texture so a whole room is one node.
    private func floorTexture(size: CGSize, style: FloorStyle, verticalOnly: Bool = false) -> SKTexture {
        let width = Int(size.width), height = Int(size.height)
        guard
            width > 0, height > 0,
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return SKTexture()
        }

        context.setFillColor(SKColor(hex: style.base).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(SKColor(hex: style.line).cgColor)

        if style.checker {
            for row in stride(from: 0, to: height, by: style.tile) {
                for column in stride(from: 0, to: width, by: style.tile) where (row / style.tile + column / style.tile) % 2 == 1 {
                    context.fill(CGRect(x: column, y: row, width: style.tile, height: style.tile))
                }
            }
        } else if style.planks {
            for row in stride(from: 0, to: height, by: style.tile) {
                context.fill(CGRect(x: 0, y: row, width: width, height: 2))
            }
        } else {
            for column in stride(from: 0, to: width, by: style.tile) {
                context.fill(CGRect(x: column, y: 0, width: 2, height: height))
            }
            if !verticalOnly {
                for row in stride(from: 0, to: height, by: style.tile) {
                    context.fill(CGRect(x: 0, y: row, width: width, height: 2))
                }
            }
        }

        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}
