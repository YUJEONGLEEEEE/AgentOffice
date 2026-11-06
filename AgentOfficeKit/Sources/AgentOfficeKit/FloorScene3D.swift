import CoreGraphics
import CoreText
import Foundation
import RealityKit
import SpriteKit

/// One floor of the office in 3D, built from blocks like the pixel art.
///
/// `FloorPlan3D` decides where everything goes; this class turns it into RealityKit entities
/// and keeps the people in step with the latest snapshots.
@MainActor
public final class FloorScene3D {

    /// Everything on the floor. Centered on the origin so the camera can turn around it.
    public let root = Entity()
    public let camera = PerspectiveCamera()

    private let plan: FloorPlan3D
    private let office = Entity()
    private var people: [String: Entity] = [:]
    private var targets: [String: CGPoint] = [:]
    private var labelKeys: [String: String] = [:]
    private var hasPlacedEveryone = false
    private var materials: [String: RealityKit.Material] = [:]
    private var labelTextures: [String: TextureResource] = [:]

    private static let skin: UInt32 = 0xF3CFAE

    private static let registration: Void = {
        PersonMotion.registerComponent()
        Blink.registerComponent()
        Rise.registerComponent()
        Wiggle.registerComponent()
        OfficeMotionSystem.registerSystem()
    }()

    public init(plan: FloorPlan3D = .standard) {
        _ = Self.registration
        self.plan = plan
        office.position = [-Float(plan.size.width) / 2, 0, -Float(plan.size.height) / 2]
        root.addChild(office)
        camera.camera.fieldOfViewInDegrees = 22
        addLights()
        buildFloor()
        buildFurniture()
        buildSeats()
        buildRoomSigns()
    }

    // MARK: - Camera

    /// Turns the camera around the floor. `yaw` turns left and right, `pitch` tilts toward looking straight down.
    public func setCamera(yaw: Float, pitch: Float, zoom: Float) {
        let distance = 64 / max(zoom, 0.1)
        let position = SIMD3<Float>(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
        camera.look(at: [0, 0.6, 0], from: position, relativeTo: nil)
    }

    // MARK: - People

    /// The agent shown by an entity, for taps. The entity may be any part of a person.
    public func agentID(for entity: Entity) -> String? {
        var current: Entity? = entity
        while let node = current {
            if let id = people.first(where: { $0.value === node })?.key { return id }
            current = node.parent
        }
        return nil
    }

    /// Moves everyone to where the latest snapshots say they are. The first call places people right away;
    /// after that, newcomers walk in from the entrance and people who leave walk out.
    public func update(agents: [AgentSnapshot]) {
        let placements = plan.placements(for: agents)
        let byID = Dictionary(agents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for (id, placement) in placements {
            guard let agent = byID[id] else { continue }
            let person = people[id] ?? makePerson(for: agent)
            if people[id] == nil {
                people[id] = person
                office.addChild(person)
                let start = hasPlacedEveryone ? plan.entrance : placement.point
                person.position = Self.floorPosition(start)
                targets[id] = start
            }
            var motion = person.components[PersonMotion.self] ?? PersonMotion()
            motion.arrivalAct = placement.act
            motion.arrivalSeated = placement.isSeated
            motion.arrivalFacing = Float(placement.facing)
            motion.leaving = false
            if targets[id] != placement.point {
                let from = CGPoint(x: Double(person.position.x), y: Double(person.position.z))
                motion.path = plan.route(from: from, to: placement.point).map { SIMD2(Float($0.x), Float($0.y)) }
                targets[id] = placement.point
            }
            person.components.set(motion)
            updateLabel(on: person, for: agent)
        }

        for (id, person) in people where placements[id] == nil {
            guard var motion = person.components[PersonMotion.self], !motion.leaving else { continue }
            let from = CGPoint(x: Double(person.position.x), y: Double(person.position.z))
            motion.path = plan.route(from: from, to: plan.entrance).map { SIMD2(Float($0.x), Float($0.y)) }
            motion.leaving = true
            person.components.set(motion)
            people[id] = nil
            targets[id] = nil
            labelKeys[id] = nil
        }
        hasPlacedEveryone = true
    }

    private func makePerson(for agent: AgentSnapshot) -> Entity {
        let appearance = AgentAppearance(id: agent.id, role: agent.role.map(TeamRole.init))
        let person = Entity()
        let figure = Entity()
        figure.name = "figure"
        person.addChild(figure)

        let pants: UInt32 = 0x3D4256
        for (name, x) in [("legL", Float(-0.17)), ("legR", Float(0.17))] {
            let pivot = Entity()
            pivot.name = name
            pivot.position = [x, 0.6, 0]
            pivot.addChild(block([0, -0.3, 0], [0.28, 0.6, 0.3], pants))
            pivot.addChild(block([0, -0.57, 0.04], [0.3, 0.08, 0.38], 0x1E1E24))
            figure.addChild(pivot)
        }
        figure.addChild(block([0, 0.95, 0], [0.72, 0.7, 0.4], appearance.shirt))
        if let tie = appearance.tie {
            figure.addChild(block([0, 1.0, 0.205], [0.12, 0.45, 0.02], tie))
        }
        for (name, x) in [("armL", Float(-0.43)), ("armR", Float(0.43))] {
            let pivot = Entity()
            pivot.name = name
            pivot.position = [x, 1.27, 0]
            pivot.addChild(block([0, -0.3, 0], [0.14, 0.6, 0.24], appearance.shirt))
            pivot.addChild(block([0, -0.63, 0], [0.13, 0.1, 0.2], Self.skin))
            if name == "armR" {
                let cup = block([0, -0.68, 0.14], [0.2, 0.22, 0.2], 0xF4F1EA)
                cup.name = "cup"
                cup.isEnabled = false
                pivot.addChild(cup)
            }
            figure.addChild(pivot)
        }
        figure.addChild(block([0, 1.575, 0], [0.6, 0.55, 0.5], Self.skin))
        figure.addChild(block([0, 1.95, 0], [0.66, 0.2, 0.56], appearance.hair))
        figure.addChild(block([0, 1.62, -0.22], [0.66, 0.5, 0.12], appearance.hair))
        for x in [Float(-0.12), Float(0.12)] {
            figure.addChild(block([x, 1.6, 0.255], [0.08, 0.08, 0.02], 0x2A2A2A))
        }
        let book = block([0, 1.05, 0.32], [0.55, 0.4, 0.08], 0xF4F1EA)
        book.name = "book"
        book.isEnabled = false
        figure.addChild(book)

        let label = ModelEntity()
        label.name = "label"
        label.position = [0, 2.55, 0]
        label.components.set(BillboardComponent())
        person.addChild(label)

        person.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: [0.9, 2.2, 0.8]).offsetBy(translation: [0, 1.1, 0])]))
        person.components.set(InputTargetComponent())
        person.components.set(PersonMotion())
        return person
    }

    /// The tag over a person: their status while busy, otherwise their name.
    private func updateLabel(on person: Entity, for agent: AgentSnapshot) {
        let busy: Set<AgentStatus> = [.working, .waiting, .arrived, .received]
        let text = busy.contains(agent.status) ? agent.status.displayName : agent.displayName
        let background = busy.contains(agent.status) ? agent.status.tagColor : 0x1D2330
        let foreground = busy.contains(agent.status) ? agent.status.tagTextColor : 0xFFFFFF
        let key = "\(text)|\(background)|\(foreground)"
        guard labelKeys[agent.id] != key, let label = person.findEntity(named: "label") as? ModelEntity else { return }
        labelKeys[agent.id] = key
        setLabel(label, key: key, text: text, background: background, foreground: foreground, height: 0.42)
    }

    private func setLabel(_ label: ModelEntity, key: String, text: String, background: UInt32, foreground: UInt32, height: Float) {
        guard let image = Self.labelImage(text: text, background: background, foreground: foreground) else { return }
        let width = height * Float(image.width) / Float(image.height)
        Task { @MainActor in
            let texture: TextureResource
            if let cached = labelTextures[key] {
                texture = cached
            } else {
                guard let made = try? await TextureResource(image: image, options: .init(semantic: .color)) else { return }
                labelTextures[key] = made
                texture = made
            }
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 1))
            label.model = ModelComponent(mesh: .generatePlane(width: width, height: height), materials: [material])
        }
    }

    /// A rounded tag with text, drawn with Core Text so it works on macOS and iOS.
    static func labelImage(text: String, background: UInt32, foreground: UInt32) -> CGImage? {
        let scale: CGFloat = 3
        let font = CTFontCreateWithName("AppleSDGothicNeo-Bold" as CFString, 15 * scale, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): SKColor(hex: foreground).cgColor,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let padding = 9 * scale, border = 2 * scale
        let width = Int(ceil(bounds.width + padding * 2)), height = Int(ceil(26 * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(SKColor(hex: 0x1D2330).cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 4 * scale, cornerHeight: 4 * scale, transform: nil))
        context.fillPath()
        context.setFillColor(SKColor(hex: background).cgColor)
        context.addPath(CGPath(roundedRect: rect.insetBy(dx: border, dy: border), cornerWidth: 3 * scale, cornerHeight: 3 * scale, transform: nil))
        context.fillPath()
        context.textPosition = CGPoint(x: padding - bounds.minX, y: (CGFloat(height) - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, context)
        return context.makeImage()
    }

    // MARK: - Building the floor

    private func addLights() {
        let key = DirectionalLight()
        key.light.intensity = 2600
        key.look(at: .zero, from: [10, 30, 18], relativeTo: nil)
        root.addChild(key)
        let fill = DirectionalLight()
        fill.light.intensity = 900
        fill.look(at: .zero, from: [-20, 14, -6], relativeTo: nil)
        root.addChild(fill)
    }

    private func buildFloor() {
        let width = Float(plan.size.width), depth = Float(plan.size.height)
        office.addChild(block([width / 2, -0.35, depth / 2], [width + 0.6, 0.5, depth + 0.6], 0x2A3146))
        for room in Room.allCases {
            let frame = plan.frame(of: room)
            office.addChild(slab(frame, color: Self.floorColor(room)))
        }
        office.addChild(slab(plan.aisle, color: 0xD8CFC0))
        // Back wall and left wall; the front stays open so the camera can look in.
        office.addChild(block([width / 2, 0.8, -0.1], [width, 1.6, 0.2], 0xD8DEE9))
        office.addChild(block([-0.1, 0.8, depth / 2], [0.2, 1.6, depth], 0xC8D0DE))
        for wall in plan.partitions {
            office.addChild(box(wall, height: 1.2, color: 0xC8D0DE))
        }
    }

    private func slab(_ frame: CGRect, color: UInt32) -> ModelEntity {
        block([Float(frame.midX), -0.05, Float(frame.midY)], [Float(frame.width), 0.1, Float(frame.height)], color)
    }

    private func buildFurniture() {
        for piece in plan.furniture {
            let f = piece.footprint
            let height = Float(piece.height), bottom = Float(piece.elevation)
            switch piece.kind {
            case .table, .desk, .lowTable:
                office.addChild(box(f, height: height, color: piece.kind == .lowTable ? 0x8A5A2B : 0xA8743F, bottom: bottom))
                office.addChild(box(f.insetBy(dx: 0.05, dy: 0.05), height: 0.06, color: 0xC99A63, bottom: bottom + height - 0.03))
            case .monitor:
                office.addChild(box(f, height: height, color: 0x1F2633, bottom: bottom))
                let front = Float(f.maxY) + 0.011
                for line in 0..<3 {
                    let bar = block([Float(f.minX) + 0.15 + Float(f.width) * 0.3, bottom + height * 0.3 + Float(line) * height * 0.2, front],
                                    [Float(f.width) * 0.55, 0.07, 0.01], line == 1 ? 0xF2B33D : 0x5BD17C, glows: true)
                    bar.components.set(Wiggle(offset: Float(line) * 0.7 + Float(f.minX)))
                    office.addChild(bar)
                }
            case .whiteboard:
                office.addChild(box(f, height: height, color: 0xFFFFFF, bottom: bottom))
                for (line, color) in [UInt32(0x2F5E8C), 0xC0392B, 0x3E8E5E, 0xD9822B].enumerated() {
                    let length = [0.55, 0.75, 0.4, 0.65][line] * Float(f.width) * 0.8
                    office.addChild(block([Float(f.minX) + 0.4 + length / 2, bottom + height - 0.35 - Float(line) * 0.4, Float(f.maxY) + 0.011],
                                          [length, 0.1, 0.01], color))
                }
            case .shelf:
                office.addChild(box(f, height: height, color: 0x7A4A2A))
                let colors: [UInt32] = [0x2F5E8C, 0xD9822B, 0x3E8E5E, 0xC0392B, 0x7B5EA7]
                for row in 0..<3 {
                    for book in 0..<4 {
                        let x = Float(f.minX) + 0.2 + Float(book) * Float(f.width - 0.3) / 4
                        office.addChild(block([x + 0.15, 0.45 + Float(row) * 0.75, Float(f.maxY) + 0.04], [0.3, 0.55, 0.08], colors[(row + book) % 5]))
                    }
                }
            case .rack:
                office.addChild(box(f, height: height, color: 0x151A26))
                for row in 0..<6 {
                    let led = block([Float(f.minX) + 0.25, 0.4 + Float(row) * 0.4, Float(f.maxY) + 0.011], [0.12, 0.12, 0.01],
                                    row % 3 == 0 ? 0xF2B33D : 0x5BD17C, glows: true)
                    led.components.set(Blink(period: 0.6 + Float(row) * 0.17, offset: Float(row) * 0.31 + Float(f.minX)))
                    office.addChild(led)
                }
            case .terminal:
                office.addChild(box(f, height: height, color: 0x3D4256))
            case .coffeeMachine:
                office.addChild(box(f, height: height, color: 0xC0392B))
                office.addChild(block([Float(f.midX), 1.2, Float(f.maxY) + 0.011], [0.6, 0.3, 0.01], 0x6EC1F0, glows: true))
                for puff in 0..<2 {
                    let steam = block([Float(f.midX) - 0.15 + Float(puff) * 0.3, height + 0.2, Float(f.midY)], [0.1, 0.25, 0.1], 0xFFFFFF)
                    steam.components.set(Rise(base: height + 0.1, height: 0.9, offset: Float(puff) * 0.5))
                    office.addChild(steam)
                }
            case .fridge:
                office.addChild(box(f, height: height, color: 0xE8ECF2))
                office.addChild(block([Float(f.maxX) - 0.15, 1.3, Float(f.maxY) + 0.02], [0.06, 0.6, 0.04], 0x9AA3B0))
            case .sofa:
                office.addChild(box(f, height: 0.45, color: 0x2F5E8C))
                office.addChild(box(CGRect(x: f.minX, y: f.maxY - 0.3, width: f.width, height: 0.3), height: height + 0.3, color: 0x2F5E8C))
            case .plant:
                office.addChild(box(f.insetBy(dx: 0.08, dy: 0.08), height: 0.4, color: 0xA0603A))
                office.addChild(box(f.insetBy(dx: -0.05, dy: -0.05), height: height - 0.4, color: 0x4F8A4A, bottom: 0.4))
            }
        }
    }

    /// A chair at every team member's seat, with its back behind the person.
    private func buildSeats() {
        for role in OfficeTeam.roster {
            guard let seat = plan.seat(forAgentType: role.agentType) else { continue }
            let chair = Entity()
            chair.position = Self.floorPosition(seat.spot.point)
            chair.orientation = simd_quatf(angle: Float(seat.spot.facing), axis: [0, 1, 0])
            chair.addChild(block([0, 0.22, 0], [0.62, 0.12, 0.6], 0x8C3B4A))
            chair.addChild(block([0, 0.55, -0.3], [0.62, 0.7, 0.1], 0x5E2532))
            chair.addChild(block([0, 0.08, 0], [0.12, 0.16, 0.12], 0x2B2D42))
            office.addChild(chair)
        }
    }

    private func buildRoomSigns() {
        for room in Room.allCases {
            let frame = plan.frame(of: room)
            let sign = ModelEntity()
            sign.position = [Float(frame.minX) + 1.1, 2.2, Float(frame.minY) + 0.35]
            sign.components.set(BillboardComponent())
            office.addChild(sign)
            let name = room == .desk ? String(localized: "Workspace", bundle: .module) : room.displayName
            setLabel(sign, key: "room|\(name)", text: name, background: 0x2E2A35, foreground: 0xFFF7E6, height: 0.5)
        }
    }

    // MARK: - Blocks

    private static func floorPosition(_ point: CGPoint) -> SIMD3<Float> {
        [Float(point.x), 0, Float(point.y)]
    }

    private func box(_ footprint: CGRect, height: Float, color: UInt32, bottom: Float = 0) -> ModelEntity {
        block([Float(footprint.midX), bottom + height / 2, Float(footprint.midY)], [Float(footprint.width), height, Float(footprint.height)], color)
    }

    private func block(_ center: SIMD3<Float>, _ size: SIMD3<Float>, _ color: UInt32, glows: Bool = false) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material(color, glows: glows)])
        entity.position = center
        return entity
    }

    private func material(_ color: UInt32, glows: Bool) -> RealityKit.Material {
        let key = "\(color)\(glows)"
        if let cached = materials[key] { return cached }
        let made: RealityKit.Material = glows
            ? UnlitMaterial(color: SKColor(hex: color))
            : SimpleMaterial(color: SKColor(hex: color), roughness: 1, isMetallic: false)
        materials[key] = made
        return made
    }

    private static func floorColor(_ room: Room) -> UInt32 {
        switch room {
        case .meetingRoom: 0x7F8FB0
        case .archive: 0xB98A5A
        case .researchRoom: 0x7FB7B2
        case .devRoom: 0x8A9A7C
        case .desk: 0xCDBA96
        case .serverRoom: 0x3A4150
        case .breakRoom: 0xE9E2D3
        }
    }
}

// MARK: - Motion

/// How a person is moving: along a path, or doing their work once they arrive.
struct PersonMotion: Component {
    var path: [SIMD2<Float>] = []
    var arrivalAct: FloorAct = .standing
    var arrivalSeated = false
    var arrivalFacing: Float = .pi
    var leaving = false
    var time: Float = 0
}

/// A light that flickers, like a server LED.
struct Blink: Component {
    var period: Float
    var offset: Float
    var time: Float = 0
}

/// Steam rising and fading over a cup of coffee.
struct Rise: Component {
    var base: Float
    var height: Float
    var offset: Float
    var time: Float = 0
}

/// Lines of code on a screen that grow and shrink as someone types.
struct Wiggle: Component {
    var offset: Float
    var time: Float = 0
}

struct OfficeMotionSystem: System {
    private static let people = EntityQuery(where: .has(PersonMotion.self))
    private static let blinks = EntityQuery(where: .has(Blink.self))
    private static let rises = EntityQuery(where: .has(Rise.self))
    private static let wiggles = EntityQuery(where: .has(Wiggle.self))
    private static let walkingSpeed: Float = 2.6

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.people, updatingSystemWhen: .rendering) {
            guard var motion = entity.components[PersonMotion.self] else { continue }
            motion.time += dt
            if let next = motion.path.first {
                let here = SIMD2(entity.position.x, entity.position.z)
                let delta = next - here
                let distance = simd_length(delta)
                let step = Self.walkingSpeed * dt
                if distance <= step {
                    entity.position = [next.x, 0, next.y]
                    motion.path.removeFirst()
                } else {
                    let move = delta / distance * step
                    entity.position += [move.x, 0, move.y]
                }
                if distance > 0.001 {
                    entity.orientation = simd_quatf(angle: atan2(delta.x, delta.y), axis: [0, 1, 0])
                }
                if motion.path.isEmpty && motion.leaving {
                    entity.removeFromParent()
                    continue
                }
                Self.pose(entity, act: nil, seated: false, time: motion.time)
            } else {
                entity.orientation = simd_quatf(angle: motion.arrivalFacing, axis: [0, 1, 0])
                Self.pose(entity, act: motion.arrivalAct, seated: motion.arrivalSeated, time: motion.time)
            }
            entity.components.set(motion)
        }

        for entity in context.entities(matching: Self.blinks, updatingSystemWhen: .rendering) {
            guard var blink = entity.components[Blink.self] else { continue }
            blink.time += dt
            entity.isEnabled = sin((blink.time + blink.offset) / blink.period * .pi * 2) > -0.6
            entity.components.set(blink)
        }
        for entity in context.entities(matching: Self.rises, updatingSystemWhen: .rendering) {
            guard var rise = entity.components[Rise.self] else { continue }
            rise.time += dt
            let progress = (rise.time * 0.7 + rise.offset).truncatingRemainder(dividingBy: 1)
            entity.position.y = rise.base + progress * rise.height
            entity.scale = .init(repeating: 1 - progress * 0.6)
            entity.components.set(rise)
        }
        for entity in context.entities(matching: Self.wiggles, updatingSystemWhen: .rendering) {
            guard var wiggle = entity.components[Wiggle.self] else { continue }
            wiggle.time += dt
            entity.scale.x = 0.45 + 0.55 * abs(sin(wiggle.time * 2.2 + wiggle.offset))
            entity.components.set(wiggle)
        }
    }

    /// Puts arms and legs in the pose for an act. `act == nil` means walking.
    private static func pose(_ person: Entity, act: FloorAct?, seated: Bool, time: Float) {
        guard let figure = person.findEntity(named: "figure") else { return }
        let armL = figure.findEntity(named: "armL"), armR = figure.findEntity(named: "armR")
        let legL = figure.findEntity(named: "legL"), legR = figure.findEntity(named: "legR")
        func tilt(_ entity: Entity?, _ angle: Float) { entity?.orientation = simd_quatf(angle: angle, axis: [1, 0, 0]) }

        figure.position.y = seated ? -0.3 : 0
        tilt(legL, seated ? -.pi / 2 : 0)
        tilt(legR, seated ? -.pi / 2 : 0)
        tilt(armL, 0)
        tilt(armR, 0)
        figure.findEntity(named: "cup")?.isEnabled = act == .coffee
        figure.findEntity(named: "book")?.isEnabled = false

        switch act {
        case nil:
            let swing = sin(time * 9) * 0.55
            tilt(legL, swing); tilt(legR, -swing)
            tilt(armL, -swing); tilt(armR, swing)
        case .typing:
            tilt(armL, -1.15 + sin(time * 16) * 0.12)
            tilt(armR, -1.15 + cos(time * 16) * 0.12)
        case .writing:
            tilt(armR, -2.4 + sin(time * 4) * 0.2)
        case .reading:
            let reading = Int(time / 3) % 2 == 1
            figure.findEntity(named: "book")?.isEnabled = reading
            tilt(armL, reading ? -0.9 : 0)
            tilt(armR, reading ? -0.9 : -2.2)
        case .coffee:
            tilt(armR, -1.35 + sin(time * 1.5) * 0.25)
        case .raisingHand:
            tilt(armR, -3.0)
            figure.position.y += abs(sin(time * 3)) * 0.08
        case .waitingAtDesk:
            tilt(armL, -0.6)
            tilt(armR, -0.6)
        case .standing:
            break
        }
    }
}
