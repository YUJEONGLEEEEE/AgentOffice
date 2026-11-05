import Cocoa
import AgentOfficeKit

/// A small card for one agent: its pixel character, name, status tag, room and last activity.
final class AgentCardView: NSView {

    static let size = NSSize(width: 210, height: 72)

    private let portrait = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let tagLabel = NSTextField(labelWithString: "")
    private let tagBackground = NSView()
    private let detailLabel = NSTextField(labelWithString: "")
    private var agentID: String?

    init() {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        portrait.wantsLayer = true
        portrait.layer?.magnificationFilter = .nearest
        portrait.layer?.contentsGravity = .resizeAspect

        nameLabel.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)

        tagBackground.wantsLayer = true
        tagBackground.layer?.cornerRadius = 4
        tagLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)

        detailLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail

        for subview in [portrait, nameLabel, tagBackground, tagLabel, detailLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size.width),
            heightAnchor.constraint(equalToConstant: Self.size.height),

            portrait.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            portrait.centerYAnchor.constraint(equalTo: centerYAnchor),
            portrait.widthAnchor.constraint(equalToConstant: 36),
            portrait.heightAnchor.constraint(equalToConstant: 48),

            nameLabel.leadingAnchor.constraint(equalTo: portrait.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            tagBackground.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            tagBackground.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            tagBackground.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            tagLabel.leadingAnchor.constraint(equalTo: tagBackground.leadingAnchor, constant: 6),
            tagLabel.trailingAnchor.constraint(equalTo: tagBackground.trailingAnchor, constant: -6),
            tagLabel.topAnchor.constraint(equalTo: tagBackground.topAnchor, constant: 2),
            tagLabel.bottomAnchor.constraint(equalTo: tagBackground.bottomAnchor, constant: -2),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Fills the card. `helpers` is the number of subagents working with this agent.
    /// `floorName` is shown when the card appears in the whole office.
    func configure(with snapshot: AgentSnapshot, helpers: Int, floorName: String?, lastActivityText: String) {
        if agentID != snapshot.id {
            agentID = snapshot.id
            portrait.layer?.contents = AgentPortrait.image(forAgentID: snapshot.id, role: snapshot.role)
        }
        nameLabel.stringValue = snapshot.name
        tagLabel.stringValue = snapshot.status.displayName
        tagLabel.textColor = NSColor(hex: snapshot.status.tagTextColor)
        tagBackground.layer?.backgroundColor = NSColor(hex: snapshot.status.tagColor).cgColor

        var details = [snapshot.status == .left ? "사무실 밖" : snapshot.room.displayName, lastActivityText]
        if let floorName {
            details.insert(floorName, at: 0)
        }
        if helpers > 0 {
            details.append("팀원 \(helpers)명")
        }
        detailLabel.stringValue = details.joined(separator: " · ")
        portrait.alphaValue = snapshot.status == .left ? 0.4 : 1
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("\(snapshot.name), \(snapshot.status.displayName), \(detailLabel.stringValue)")
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    /// Layer colors do not follow light and dark mode by themselves, so set them again on change.
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
