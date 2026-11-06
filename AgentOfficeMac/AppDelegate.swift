//
//  AppDelegate.swift
//  AgentOfficeMac
//
//  Created by 이유정 on 10/24/26.
//

import Cocoa
import AgentOfficeKit

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// The app has a single window, so closing it quits, like System Settings.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// The office window, which the menu commands act on.
    private var office: ViewController? {
        let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.contentViewController is ViewController }
        return window?.contentViewController as? ViewController
    }

    /// File > Choose Events Folder… (⌘O), passed on to the office window.
    @objc func chooseEventsFolder(_ sender: Any?) {
        office?.chooseEventsFolder(sender)
    }

    /// View > 2D (⌘1)
    @objc func showFlatOffice(_ sender: Any?) {
        office?.show(style: .flat)
    }

    /// View > 3D (⌘2)
    @objc func showBuilding(_ sender: Any?) {
        office?.show(style: .building)
    }

    /// Puts a check mark next to the view style in use.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(showFlatOffice(_:)):
            menuItem.state = office?.viewStyle == .flat ? .on : .off
            return office != nil
        case #selector(showBuilding(_:)):
            menuItem.state = office?.viewStyle == .building ? .on : .off
            return office != nil
        default:
            return true
        }
    }
}
