import AppKit
import AgentOfficeKit

/// The menu bar. AgentOffice only shows the office, so it keeps the standard menus
/// a viewer app needs and leaves out document commands like Save and Print.
enum MainMenu {

    static let appName = "AgentOffice"

    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        for menu in [appMenu(), fileMenu(), viewMenu(), windowMenu(), helpMenu()] {
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        return mainMenu
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: appName)
        menu.addItem(withTitle: String(localized: "About \(appName)"),
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())

        let services = NSMenu(title: String(localized: "Services"))
        menu.addItem(withTitle: services.title, action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        menu.addItem(.separator())

        menu.addItem(withTitle: String(localized: "Hide \(appName)"),
                     action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: String(localized: "Hide Others"),
                                      action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: String(localized: "Show All"),
                     action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())

        menu.addItem(withTitle: String(localized: "Quit \(appName)"),
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "File"))
        menu.addItem(withTitle: String(localized: "Choose Events Folder…"),
                     action: #selector(AppDelegate.chooseEventsFolder(_:)), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Close Window"),
                     action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    /// The two ways to see the office. macOS adds "Enter Full Screen" to this menu by itself.
    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "View"))
        menu.addItem(withTitle: OfficeViewStyle.flat.title, action: #selector(AppDelegate.showFlatOffice(_:)), keyEquivalent: "1")
        menu.addItem(withTitle: OfficeViewStyle.building.title, action: #selector(AppDelegate.showBuilding(_:)), keyEquivalent: "2")
        menu.addItem(.separator())
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Window"))
        menu.addItem(withTitle: String(localized: "Minimize"),
                     action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: String(localized: "Zoom"),
                     action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Bring All to Front"),
                     action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = menu
        return menu
    }

    /// macOS adds the search field for menu commands to this menu by itself.
    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Help"))
        NSApp.helpMenu = menu
        return menu
    }
}
