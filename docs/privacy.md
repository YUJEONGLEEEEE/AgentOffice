---
title: Privacy Policy
permalink: /privacy
---

# AgentOffice Privacy Policy

*Effective November 17, 2026* · [한국어](privacy-ko)

AgentOffice shows your Claude Code sessions as a pixel-art office on your Mac and iPhone. It is built to show *what kind of work* is happening, never the work itself.

**In short:** the developer runs no servers and collects nothing. Your data stays on your devices and in your own private iCloud database. There are no analytics, ads or tracking, and nothing is shared with third parties.

## What is recorded on your Mac

The AgentOffice plugin for Claude Code writes a small log for each session in `~/Library/Application Support/AgentOffice/Events`, readable only by your macOS account. Each line holds only:

- the time and the kind of event (for example, a tool started or a session ended)
- the session ID, and the ID and type of a subagent, such as "ios-developer"
- the tool name, such as "Bash" or "Read"
- the project **folder name** (not its full path), and a number that identifies that folder on your Mac, so a renamed folder keeps its floor
- the kind of notification, and why a session started or ended

Prompts, tool inputs, commands, file contents and full paths are **never** recorded.

**Permission questions are the one exception.** When Claude Code asks for permission to use a tool while the Mac app is open, the plugin writes the question to `~/Library/Application Support/AgentOffice/Approvals`, including a one-line summary of the command or file it is about, so you can decide safely. The file is readable only by your macOS account and is deleted as soon as the question is answered, here, on your iPhone or in the terminal.

## What goes to iCloud

To show the office on your iPhone, the Mac app saves data to **your private iCloud database**. Only your Apple Account can read it; the developer cannot.

- For each person in the office: a short name, the project folder name, the room, the status, the role and the time of the last activity.
- The time the Mac last checked in.
- For each open permission question: the session ID, the subagent ID, the employee's short name, the project folder name, the tool name, the time, and your answer once you give one. The command or file summary is stored with **end-to-end encryption**, so only your own devices can read it, not even Apple. Each question is deleted when it is answered.

When a new question arrives, iCloud sends your iPhone a notification through Apple's push service. It names only the employee and the tool, never the command.

## Permissions the apps ask for

- **Mac: a folder you choose.** The app runs in the App Sandbox and uses only the AgentOffice folder you pick.
- **Mac and iPhone: notifications**, to tell you about permission questions. You can turn them off in Settings at any time.
- **iCloud**, to sync the office between your Mac and iPhone. Without iCloud, the Mac app still works on its own.

## Demo office

The demo office is made up on the device. It is never saved, sent to iCloud or passed to Claude Code, and answering its permission question runs nothing.

## Crash reports

If you choose to share crash reports or analytics with app developers in your device settings, Apple may send the developer anonymous crash reports. This is controlled by Apple and you, not by AgentOffice.

## Deleting your data

- **On your Mac:** delete the folder `~/Library/Application Support/AgentOffice`. To stop recording, uninstall the plugin in Claude Code.
- **In iCloud:** open the iPhone Settings app, tap your name, then **iCloud**, and manage the storage for AgentOffice. Data in iCloud is also replaced as the office changes.

## Children

AgentOffice is a tool for software developers and is not directed at children.

## Changes

If this policy changes, the new version will be posted on this page with a new effective date. The history of every change is public in the [project repository](https://github.com/YUJEONGLEEEEE/AgentOffice/commits/main/docs/privacy.md).

## Contact

Questions about privacy: please open an issue at [github.com/YUJEONGLEEEEE/AgentOffice/issues](https://github.com/YUJEONGLEEEEE/AgentOffice/issues).

AgentOffice is an independent project and is not affiliated with or endorsed by Anthropic.
