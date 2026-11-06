import CoreGraphics

/// The cutaway of the office building: one floor per project, stacked from the ground up.
///
/// Like `OfficeLayout`, frames use a top-left origin. Each floor is split into the same rooms
/// in the same order, so an agent's room reads the same on every floor.
public struct BuildingLayout: Equatable, Sendable {

    /// The rooms on every floor, left to right.
    public static let roomOrder: [Room] = [.meetingRoom, .archive, .researchRoom, .devRoom, .desk, .serverRoom, .breakRoom]

    /// Shares of the floor width. The shared workspace is wider because most desks are there.
    private static let roomWeights: [Room: CGFloat] = [
        .meetingRoom: 1, .archive: 1, .researchRoom: 1, .devRoom: 1.1, .desk: 1.3, .serverRoom: 0.8, .breakRoom: 0.9,
    ]

    public static let width: CGFloat = 1160
    /// The height the building fits in. With many floors it grows so floors never get too thin.
    public static let minimumHeight: CGFloat = 640
    public static let roofHeight: CGFloat = 46
    public static let lobbyHeight: CGFloat = 40
    public static let preferredFloorHeight: CGFloat = 128
    public static let minimumFloorHeight: CGFloat = 56
    /// The column on the left of each floor with its number and name.
    public static let labelWidth: CGFloat = 150
    public static let sideMargin: CGFloat = 24
    public static let slabHeight: CGFloat = 6

    /// Floor names from the top floor down.
    public let floorsTopDown: [String]
    public let size: CGSize
    public let floorHeight: CGFloat

    /// `floors` are listed in any order; they are numbered 1F, 2F, … in that order from the ground up.
    public init(floors: [String]) {
        floorsTopDown = floors.reversed()
        let count = CGFloat(max(floors.count, 1))
        let space = Self.minimumHeight - Self.roofHeight - Self.lobbyHeight
        floorHeight = max(Self.minimumFloorHeight, min(Self.preferredFloorHeight, space / count))
        let height = max(Self.minimumHeight, Self.roofHeight + Self.lobbyHeight + floorHeight * count)
        size = CGSize(width: Self.width, height: height)
    }

    /// The floor number shown on the building, counting from 1 at the bottom.
    public func level(of floor: String) -> Int? {
        floorsTopDown.firstIndex(of: floor).map { floorsTopDown.count - $0 }
    }

    /// The whole floor, from its label column to its last room, including the slab under it.
    public func frame(ofFloor floor: String) -> CGRect? {
        guard let index = floorsTopDown.firstIndex(of: floor) else { return nil }
        let stackHeight = floorHeight * CGFloat(floorsTopDown.count)
        // Floors sit on the lobby; extra space when there are few floors stays above them as sky.
        let top = size.height - Self.lobbyHeight - stackHeight + floorHeight * CGFloat(index)
        return CGRect(x: Self.sideMargin, y: top, width: size.width - Self.sideMargin * 2, height: floorHeight)
    }

    /// The part of the floor with rooms, without the label column and the slab.
    public func interior(ofFloor floor: String) -> CGRect? {
        frame(ofFloor: floor).map {
            CGRect(x: $0.minX + Self.labelWidth, y: $0.minY, width: $0.width - Self.labelWidth, height: $0.height - Self.slabHeight)
        }
    }

    public func frame(of room: Room, onFloor floor: String) -> CGRect? {
        guard let interior = interior(ofFloor: floor),
              let index = Self.roomOrder.firstIndex(of: room) else { return nil }
        let total = Self.roomOrder.reduce(0) { $0 + (Self.roomWeights[$1] ?? 1) }
        let unit = interior.width / total
        let before = Self.roomOrder.prefix(index).reduce(0) { $0 + (Self.roomWeights[$1] ?? 1) }
        return CGRect(x: interior.minX + before * unit, y: interior.minY,
                      width: (Self.roomWeights[room] ?? 1) * unit, height: interior.height)
    }

    /// Where the `index`-th agent in a room stands: on the room's floor line, spread across the room.
    /// Agents beyond what fits share the last places, a little apart.
    public func spot(in room: Room, onFloor floor: String, index: Int) -> CGPoint? {
        guard let frame = frame(of: room, onFloor: floor) else { return nil }
        let spacing: CGFloat = 34
        let fits = max(1, Int((frame.width - 24) / spacing))
        let column = index % fits
        let row = index / fits
        return CGPoint(x: frame.minX + 24 + CGFloat(column) * spacing + CGFloat(row) * 12, y: frame.maxY - 6)
    }

    /// The floor under a point, for clicks and taps.
    public func floor(at point: CGPoint) -> String? {
        floorsTopDown.first { frame(ofFloor: $0)?.contains(point) == true }
    }

    // MARK: - SpriteKit coordinates

    public func sceneRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
    }

    public func scenePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }

    public func layoutPoint(_ scenePoint: CGPoint) -> CGPoint {
        CGPoint(x: scenePoint.x, y: size.height - scenePoint.y)
    }
}
