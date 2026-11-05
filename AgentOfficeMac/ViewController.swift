//
//  ViewController.swift
//  AgentOfficeMac
//
//  Created by 이유정 on 10/24/26.
//

import Cocoa
import SpriteKit
import AgentOfficeKit

/// The office window: floor buttons on the left, the office floor in the middle,
/// the activity log on the right and a card for each agent at the bottom.
class ViewController: NSViewController {

    private static let refreshInterval: TimeInterval = 2
    private static let floorListWidth: CGFloat = 180
    private static let activityListWidth: CGFloat = 270

    private let folderAccess = EventFolderAccess()
    private var office = SessionStore.Office()
    private var snapshots: [AgentSnapshot] = []
    private var floors: [FloorSummary] = []
    private var floorActivity: [ActivityEntry] = []
    /// The floor the user picked. `nil` shows the whole office with every project's agents.
    private var chosenFloor: String?
    private var shownFloor: String?
    /// The first row of the floor list is "전체" (every floor); the floors follow.
    private static let allFloorsRow = 0
    private var isUpdatingFloorSelection = false
    private var refreshTimer: Timer?

    private let folderLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "기록 폴더 선택…", target: nil, action: nil)
    private let floorTable = NSTableView()
    private let officeView = SKView()
    private let officeScene = OfficeScene(layout: .standard)
    private let activityTable = NSTableView()
    private let cardStack = NSStackView()
    private var cardViews: [String: AgentCardView] = [:]
    private let emptyStateLabel = NSTextField(labelWithString: "")

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpHeader()
        let floorPanel = makeFloorPanel()
        let activityPanel = makeActivityPanel()
        let cardScroll = makeCardStrip()
        setUpOffice()
        setUpEmptyState()
        layOut(floorPanel: floorPanel, activityPanel: activityPanel, cardScroll: cardScroll)

        if folderAccess.restore() != nil {
            reload()
            startRefreshing()
        }
        updateFolderUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard let window = view.window else { return }
        window.title = "AgentOffice"
        window.minSize = NSSize(width: 1100, height: 600)
        if window.frame.width < 1100 {
            let visible = window.screen?.visibleFrame.size ?? NSSize(width: 1400, height: 800)
            window.setContentSize(NSSize(width: min(1400, visible.width - 40), height: min(700, visible.height - 40)))
            window.center()
        }
    }

    // MARK: - Layout

    private func setUpHeader() {
        folderLabel.textColor = .secondaryLabelColor
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolder)
        chooseFolderButton.bezelStyle = .push
    }

    private func makeFloorPanel() -> NSView {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("floor"))
        floorTable.addTableColumn(column)
        floorTable.headerView = nil
        floorTable.style = .sourceList
        floorTable.rowHeight = 40
        floorTable.dataSource = self
        floorTable.delegate = self
        floorTable.setAccessibilityLabel("층")
        return makePanel(title: "층", table: floorTable)
    }

    private func makeActivityPanel() -> NSView {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("activity"))
        activityTable.addTableColumn(column)
        activityTable.headerView = nil
        activityTable.style = .plain
        activityTable.rowHeight = 40
        activityTable.selectionHighlightStyle = .none
        activityTable.dataSource = self
        activityTable.delegate = self
        activityTable.setAccessibilityLabel("활동 기록")
        return makePanel(title: "활동 기록", table: activityTable)
    }

    private func makePanel(title: String, table: NSTableView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .preferredFont(forTextStyle: .headline)

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let panel = NSStackView(views: [titleLabel, scrollView])
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 6
        scrollView.widthAnchor.constraint(equalTo: panel.widthAnchor).isActive = true
        return panel
    }

    private func makeCardStrip() -> NSScrollView {
        cardStack.orientation = .horizontal
        cardStack.spacing = 10
        cardStack.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.documentView = cardStack
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.setAccessibilityLabel("직원 카드")

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            cardStack.heightAnchor.constraint(equalToConstant: AgentCardView.size.height),
        ])
        return scrollView
    }

    private func setUpOffice() {
        officeView.ignoresSiblingOrder = true
        officeView.presentScene(officeScene)
    }

    private func setUpEmptyState() {
        emptyStateLabel.font = .preferredFont(forTextStyle: .title3)
        emptyStateLabel.textColor = .white
        emptyStateLabel.alignment = .center
        emptyStateLabel.wantsLayer = true
        emptyStateLabel.drawsBackground = true
        emptyStateLabel.backgroundColor = NSColor.black.withAlphaComponent(0.6)
    }

    private func layOut(floorPanel: NSView, activityPanel: NSView, cardScroll: NSScrollView) {
        let header = NSStackView(views: [folderLabel, chooseFolderButton])
        header.orientation = .horizontal
        header.spacing = 12

        // The office keeps its shape and grows as large as the space between the panels allows.
        let officeArea = NSLayoutGuide()
        view.addLayoutGuide(officeArea)

        for subview in [header, floorPanel, officeView, activityPanel, cardScroll, emptyStateLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let layout = OfficeLayout.standard
        let keepAspectRatio = officeView.heightAnchor.constraint(
            equalTo: officeView.widthAnchor,
            multiplier: layout.size.height / layout.size.width
        )
        let fillWidth = officeView.widthAnchor.constraint(equalTo: officeArea.widthAnchor)
        // Below the window's own size priority, so the office fills the window instead of growing it.
        fillWidth.priority = .defaultLow
        let fillHeight = officeView.heightAnchor.constraint(equalTo: officeArea.heightAnchor)
        fillHeight.priority = .defaultLow - 1

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            floorPanel.topAnchor.constraint(equalTo: officeArea.topAnchor),
            floorPanel.bottomAnchor.constraint(equalTo: officeArea.bottomAnchor),
            floorPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            floorPanel.widthAnchor.constraint(equalToConstant: Self.floorListWidth),

            officeArea.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            officeArea.leadingAnchor.constraint(equalTo: floorPanel.trailingAnchor, constant: 16),
            officeArea.trailingAnchor.constraint(equalTo: activityPanel.leadingAnchor, constant: -16),
            officeArea.bottomAnchor.constraint(equalTo: cardScroll.topAnchor, constant: -14),

            keepAspectRatio,
            officeView.centerXAnchor.constraint(equalTo: officeArea.centerXAnchor),
            officeView.centerYAnchor.constraint(equalTo: officeArea.centerYAnchor),
            officeView.widthAnchor.constraint(lessThanOrEqualTo: officeArea.widthAnchor),
            officeView.heightAnchor.constraint(lessThanOrEqualTo: officeArea.heightAnchor),
            fillWidth,
            fillHeight,

            activityPanel.topAnchor.constraint(equalTo: officeArea.topAnchor),
            activityPanel.bottomAnchor.constraint(equalTo: officeArea.bottomAnchor),
            activityPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            activityPanel.widthAnchor.constraint(equalToConstant: Self.activityListWidth),

            cardScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardScroll.heightAnchor.constraint(equalToConstant: AgentCardView.size.height + 18),
            cardScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            emptyStateLabel.centerXAnchor.constraint(equalTo: officeView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: officeView.centerYAnchor),
        ])
    }

    // MARK: - Folder

    @objc private func chooseFolder() {
        guard let window = view.window else { return }
        folderAccess.chooseFolder(for: window) { [weak self] url in
            guard let self, url != nil else { return }
            self.updateFolderUI()
            self.reload()
            self.startRefreshing()
        }
    }

    private func updateFolderUI() {
        if let url = folderAccess.folderURL {
            folderLabel.stringValue = "기록 폴더: \(url.lastPathComponent)"
            folderLabel.toolTip = url.path(percentEncoded: false)
            chooseFolderButton.title = "폴더 바꾸기…"
        } else {
            folderLabel.stringValue = "기록 폴더를 선택하면 사무실 현황이 보여요."
            folderLabel.toolTip = nil
            chooseFolderButton.title = "기록 폴더 선택…"
        }
        updateEmptyState()
    }

    // MARK: - Data

    private func startRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reload()
            }
        }
    }

    private func reload() {
        guard let folderURL = folderAccess.folderURL else { return }
        let now = Date.now
        office = SessionStore(folderURL: folderURL).load(now: now)
        snapshots = office.sessions.map { $0.snapshot(at: now) }
        floors = FloorSummary.floors(from: snapshots)
        updateFloor(now: now)
    }

    /// Shows the chosen floor, or every floor together when nothing is chosen.
    private func updateFloor(now: Date) {
        if let chosenFloor, !floors.contains(where: { $0.name == chosenFloor }) {
            self.chosenFloor = nil
        }
        let floor = chosenFloor

        if floor != shownFloor {
            // A new floor appears right away instead of everyone walking out of the elevator.
            officeScene.removeAllAgents()
            shownFloor = floor
        }

        let agents = floor.map { name in snapshots.filter { $0.floor == name } } ?? snapshots
        // In the whole office, name plates also say which project each agent works on.
        officeScene.show(agents: floor == nil ? agents.map(Self.withProjectName) : agents)
        floorActivity = floor.map { name in office.activity.filter { $0.floor == name } } ?? office.activity
        view.window?.subtitle = floor.map { "\($0) 층" } ?? "전체"

        reloadFloorTable()
        activityTable.reloadData()
        updateCards(agents: agents, now: now)
        updateEmptyState()
    }

    private func reloadFloorTable() {
        isUpdatingFloorSelection = true
        floorTable.reloadData()
        let row = shownFloor.flatMap { name in floors.firstIndex { $0.name == name }.map { $0 + 1 } } ?? Self.allFloorsRow
        floorTable.selectRowIndexes([row], byExtendingSelection: false)
        isUpdatingFloorSelection = false
    }

    private func updateCards(agents: [AgentSnapshot], now: Date) {
        let sessionsByID = Dictionary(uniqueKeysWithValues: office.sessions.map { ($0.id, $0) })
        let ordered = agents.sorted { ($0.status == .left ? 1 : 0, $1.lastActivity) < ($1.status == .left ? 1 : 0, $0.lastActivity) }

        var cards: [AgentCardView] = []
        for agent in ordered {
            let card = cardViews[agent.id] ?? AgentCardView()
            cardViews[agent.id] = card
            card.configure(
                with: agent,
                helpers: sessionsByID[agent.id]?.activeSubagentIDs.count ?? 0,
                floorName: shownFloor == nil ? agent.floor : nil,
                lastActivityText: lastActivityText(for: agent.lastActivity, now: now)
            )
            cards.append(card)
        }

        let shownIDs = Set(ordered.map(\.id))
        cardViews = cardViews.filter { shownIDs.contains($0.key) }
        if cardStack.arrangedSubviews != cards {
            cardStack.setViews(cards, in: .leading)
        }
    }

    private func updateEmptyState() {
        if folderAccess.folderURL == nil {
            emptyStateLabel.stringValue = "  기록 폴더를 아직 선택하지 않았어요  "
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.stringValue = "  아직 출근한 직원이 없어요  "
            emptyStateLabel.isHidden = !snapshots.isEmpty
        }
    }

    /// "eebe · AgentOffice". Long project names are shortened so the name plate stays small.
    private static func withProjectName(_ agent: AgentSnapshot) -> AgentSnapshot {
        let project = agent.floor.count > 12 ? agent.floor.prefix(11) + "…" : Substring(agent.floor)
        return AgentSnapshot(id: agent.id, name: "\(agent.name) · \(project)", floor: agent.floor,
                             room: agent.room, status: agent.status, lastActivity: agent.lastActivity)
    }

    private func lastActivityText(for date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 10 {
            return "방금"
        }
        return relativeFormatter.localizedString(for: date, relativeTo: now)
    }
}

// MARK: - NSTableViewDataSource, NSTableViewDelegate

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === floorTable ? floors.count + 1 : floorActivity.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: TwoLineCell.identifier, owner: self) as? TwoLineCell ?? TwoLineCell()

        if tableView === floorTable {
            let isAll = row == Self.allFloorsRow
            let name = isAll ? "전체" : floors[row - 1].name
            let count = isAll ? floors.reduce(0) { $0 + $1.presentCount } : floors[row - 1].presentCount
            cell.titleField.stringValue = name
            cell.subtitleField.stringValue = count > 0 ? "\(count)명 근무 중" : "비어 있음"
        } else {
            let entry = floorActivity[row]
            var parts = [entry.agentName, timeFormatter.string(from: entry.time)]
            if shownFloor == nil {
                parts.insert(entry.floor, at: 1)
            }
            cell.titleField.stringValue = entry.summary
            cell.subtitleField.stringValue = parts.joined(separator: " · ")
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isUpdatingFloorSelection,
              notification.object as? NSTableView === floorTable,
              floorTable.selectedRow >= 0 else { return }
        let row = floorTable.selectedRow
        chosenFloor = row == Self.allFloorsRow ? nil : floors[row - 1].name
        updateFloor(now: .now)
    }
}

/// A table cell with a title and a smaller line below it.
private final class TwoLineCell: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("TwoLineCell")

    let titleField = NSTextField(labelWithString: "")
    let subtitleField = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        textField = titleField

        titleField.lineBreakMode = .byTruncatingTail
        subtitleField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [titleField, subtitleField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
