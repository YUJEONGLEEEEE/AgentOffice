//
//  ViewController.swift
//  AgentOffice
//
//  Created by 이유정 on 10/23/26.
//

import UIKit
import SpriteKit
import AgentOfficeKit

/// The iPhone office: the same floor as the Mac, read from iCloud. View only.
class ViewController: UIViewController {

    private static let refreshInterval: TimeInterval = 10
    /// The Mac sends a heartbeat every minute. Longer silence means it is off or asleep.
    private static let offlineAfter: TimeInterval = 150

    private let cloud = OfficeCloud()
    private var agents: [AgentSnapshot] = []
    private var lastUpdated: Date?
    private var chosenFloor: String?
    private var shownFloor: String?
    private var shownAgents: [AgentSnapshot] = []
    private var refreshTimer: Timer?
    private var isLoading = false

    private let statusLabel = UILabel()
    private let officeView = SKView()
    private let officeScene = OfficeScene(layout: .standard)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let messageLabel = UILabel()

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = OfficeText.allFloors
        view.backgroundColor = .systemGroupedBackground
        setUpViews()
        updateFloorMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startRefreshing()
    }

    // MARK: - Layout

    private func setUpViews() {
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        officeView.ignoresSiblingOrder = true
        officeView.layer.cornerRadius = 10
        officeView.clipsToBounds = true
        officeView.presentScene(officeScene)
        officeView.isAccessibilityElement = true
        officeView.accessibilityLabel = OfficeText.office

        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "agent")
        tableView.allowsSelection = false
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = String(localized: "Loading…")

        for subview in [statusLabel, officeView, tableView, messageLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let layout = OfficeLayout.standard
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            officeView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            officeView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            officeView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            officeView.heightAnchor.constraint(equalTo: officeView.widthAnchor,
                                               multiplier: layout.size.height / layout.size.width),

            tableView.topAnchor.constraint(equalTo: officeView.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            messageLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32),
        ])
    }

    /// The floor menu: "All" and one item per project, with a check on the one shown.
    private func updateFloorMenu() {
        let floors = FloorSummary.floors(from: agents)
        let all = UIAction(title: OfficeText.allFloors, state: chosenFloor == nil ? .on : .off) { [weak self] _ in
            self?.choose(floor: nil)
        }
        let floorActions = floors.map { floor in
            UIAction(title: floor.name, subtitle: floor.presentCount > 0 ? OfficeText.atWork(floor.presentCount) : OfficeText.emptyFloor,
                     state: chosenFloor == floor.name ? .on : .off) { [weak self] _ in
                self?.choose(floor: floor.name)
            }
        }
        let menu = UIMenu(title: String(localized: "Floors"), children: [all, UIMenu(options: .displayInline, children: floorActions)])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: String(localized: "Floors"), image: UIImage(systemName: "building.2"), menu: menu)
    }

    private func choose(floor: String?) {
        chosenFloor = floor
        showOffice()
    }

    // MARK: - Data

    @objc private func appDidBecomeActive() {
        startRefreshing()
    }

    @objc private func appWillResignActive() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func pullToRefresh() {
        load()
    }

    private func startRefreshing() {
        load()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.load()
            }
        }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let office = try await cloud.fetch()
                agents = office.agents
                lastUpdated = office.lastUpdated
                messageLabel.text = agents.isEmpty ? String(localized: "No one is in the office yet.\nOpen AgentOffice on your Mac.") : nil
            } catch OfficeCloud.CloudError.accountUnavailable {
                messageLabel.text = String(localized: "Sign in to iCloud in Settings\nto see the office on your Mac.")
            } catch {
                messageLabel.text = agents.isEmpty ? String(localized: "Couldn’t load the office.\nTrying again soon.") : nil
            }
            isLoading = false
            tableView.refreshControl?.endRefreshing()
            showOffice()
        }
    }

    private func showOffice() {
        let now = Date.now
        if let chosenFloor, !agents.contains(where: { $0.floor == chosenFloor }) {
            self.chosenFloor = nil
        }
        let floor = chosenFloor
        if floor != shownFloor {
            officeScene.removeAllAgents()
            shownFloor = floor
        }
        title = floor ?? OfficeText.allFloors

        // Apply the one-hour rule here too, in case the Mac stopped sending updates.
        let current = agents.map { agent in
            AgentSnapshot(id: agent.id, name: agent.name, floor: agent.floor, room: agent.room,
                          status: agent.status(at: now), lastActivity: agent.lastActivity, role: agent.role)
        }
        // The team is always in the office; members with work on this floor show that work.
        let onFloor = OfficeTeam.arrange(floor.map { name in current.filter { $0.floor == name } } ?? current)
        officeScene.show(agents: onFloor)
        shownAgents = onFloor.sorted { ($0.status == .left ? 1 : 0, $1.lastActivity) < ($1.status == .left ? 1 : 0, $0.lastActivity) }

        updateStatusLabel(now: now)
        updateFloorMenu()
        tableView.reloadData()
        messageLabel.isHidden = messageLabel.text == nil || !shownAgents.isEmpty
    }

    private func updateStatusLabel(now: Date) {
        let working = shownAgents.filter { $0.status != .left && $0.status != .idle }.count
        guard let lastUpdated else {
            statusLabel.text = nil
            return
        }
        let updatedText = now.timeIntervalSince(lastUpdated) < 30 ? OfficeText.justNow : relativeFormatter.localizedString(for: lastUpdated, relativeTo: now)
        if now.timeIntervalSince(lastUpdated) > Self.offlineAfter {
            statusLabel.text = String(localized: "Mac offline · Last updated \(updatedText)")
            statusLabel.textColor = .systemOrange
        } else {
            statusLabel.text = String(localized: "\(working) at work · Updated \(updatedText)")
            statusLabel.textColor = .secondaryLabel
        }
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        shownAgents.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        shownAgents.isEmpty ? nil : String(localized: "Staff")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "agent", for: indexPath)
        let agent = shownAgents[indexPath.row]

        var content = UIListContentConfiguration.subtitleCell()
        content.text = agent.displayName
        var details = [agent.status.displayName, agent.status == .left ? OfficeText.outOfOffice : agent.room.displayName]
        if shownFloor == nil && !agent.floor.isEmpty {
            details.append(agent.floor)
        }
        content.secondaryText = details.joined(separator: " · ")
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = Self.portrait(for: agent)
        content.imageProperties.maximumSize = CGSize(width: 27, height: 36)
        cell.contentConfiguration = content
        cell.contentView.alpha = agent.status == .left ? 0.5 : 1
        return cell
    }

    /// The pixel character, scaled up without smoothing so the pixels stay sharp.
    private static func portrait(for agent: AgentSnapshot) -> UIImage? {
        guard let pixels = AgentPortrait.image(forAgentID: agent.id, role: agent.role) else { return nil }
        let size = CGSize(width: pixels.width * 3, height: pixels.height * 3)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .none
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.draw(pixels, in: CGRect(origin: .zero, size: size))
        }
    }
}
