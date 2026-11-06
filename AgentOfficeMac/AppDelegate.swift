//
//  AppDelegate.swift
//  AgentOfficeMac
//
//  Created by 이유정 on 10/24/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

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

    /// File > Choose Events Folder… (⌘O), passed on to the office window.
    @objc func chooseEventsFolder(_ sender: Any?) {
        let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.contentViewController is ViewController }
        guard let office = window?.contentViewController as? ViewController else { return }
        office.chooseEventsFolder(sender)
    }
}
