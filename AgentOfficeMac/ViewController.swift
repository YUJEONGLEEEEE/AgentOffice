//
//  ViewController.swift
//  AgentOfficeMac
//
//  Created by 이유정 on 10/24/26.
//

import Cocoa
import SpriteKit
import AgentOfficeKit

/// Shows the office floor, and every recent Claude Code session as a row:
/// floor (project), agent, room, status and last activity.
class ViewController: NSViewController {

    private enum Column: String, CaseIterable {
        case floor, agent, room, status, lastActivity

        var title: String {
            switch self {
            case .floor: "층"
            case .agent: "직원"
            case .room: "지금 있는 방"
            case .status: "상태"
            case .lastActivity: "마지막 활동"
            }
        }

        var width: CGFloat {
            switch self {
            case .floor: 160
            case .agent: 140
            case .room: 120
            case .status: 110
            case .lastActivity: 120
            }
        }
    }

    private static let refreshInterval: TimeInterval = 2

    private let folderAccess = EventFolderAccess()
    private var sessions: [AgentSession] = []
    private var refreshTimer: Timer?

    private let officeView = SKView()
    private let officeScene = OfficeScene(layout: .standard)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let folderLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "기록 폴더 선택…", target: nil, action: nil)
    private let emptyStateLabel = NSTextField(labelWithString: "")

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpHeader()
        setUpOffice()
        setUpTable()
        setUpEmptyState()

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
        window.minSize = NSSize(width: 820, height: 640)
        if window.frame.width < 1000 {
            window.setContentSize(NSSize(width: 1100, height: 860))
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

        let header = NSStackView(views: [folderLabel, chooseFolderButton])
        header.orientation = .horizontal
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func setUpOffice() {
        officeView.ignoresSiblingOrder = true
        officeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(officeView)

        let layout = OfficeLayout.standard
        let keepAspectRatio = officeView.heightAnchor.constraint(
            equalTo: officeView.widthAnchor,
            multiplier: layout.size.height / layout.size.width
        )
        keepAspectRatio.priority = .defaultHigh

        NSLayoutConstraint.activate([
            officeView.topAnchor.constraint(equalTo: chooseFolderButton.bottomAnchor, constant: 12),
            officeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            officeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            keepAspectRatio,
        ])

        officeView.presentScene(officeScene)
    }

    private func setUpTable() {
        for column in Column.allCases {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableView.addTableColumn(tableColumn)
        }
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: officeView.bottomAnchor, constant: 12),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setUpEmptyState() {
        emptyStateLabel.font = .preferredFont(forTextStyle: .title3)
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
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
        sessions = SessionStore(folderURL: folderURL).loadSessions(now: now)
        tableView.reloadData()
        updateEmptyState()
        updateOffice(now: now)
    }

    /// Shows the floor of the most recently active agent. Choosing a floor comes later.
    private func updateOffice(now: Date) {
        let snapshots = sessions.map { $0.snapshot(at: now) }
        let floor = snapshots.first?.floor
        officeScene.show(agents: snapshots.filter { $0.floor == floor })
        view.window?.subtitle = floor.map { "\($0) 층" } ?? ""
    }

    private func updateEmptyState() {
        if folderAccess.folderURL == nil {
            emptyStateLabel.stringValue = "기록 폴더를 아직 선택하지 않았어요"
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.stringValue = "아직 출근한 직원이 없어요"
            emptyStateLabel.isHidden = !sessions.isEmpty
        }
    }

    private func text(for column: Column, session: AgentSession, now: Date) -> String {
        let status = session.status(at: now)
        switch column {
        case .floor:
            return session.project
        case .agent:
            let shortID = session.id.prefix(4)
            let helpers = session.activeSubagentIDs.count
            return helpers > 0 ? "세션 \(shortID)… (+팀원 \(helpers))" : "세션 \(shortID)…"
        case .room:
            return status == .left ? "–" : session.room.displayName
        case .status:
            return status.displayName
        case .lastActivity:
            if now.timeIntervalSince(session.lastActivity) < 10 {
                return "방금"
            }
            return relativeFormatter.localizedString(for: session.lastActivity, relativeTo: now)
        }
    }
}

// MARK: - NSTableViewDataSource, NSTableViewDelegate

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        sessions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard
            let tableColumn,
            let column = Column(rawValue: tableColumn.identifier.rawValue)
        else { return nil }

        let session = sessions[row]
        let now = Date.now
        let identifier = tableColumn.identifier

        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: identifier)
        cell.textField?.stringValue = text(for: column, session: session, now: now)
        cell.textField?.textColor = session.status(at: now) == .left ? .secondaryLabelColor : .labelColor
        return cell
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
