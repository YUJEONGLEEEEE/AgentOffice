# Changelog

All notable changes to this project are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-11-17

### Added
- Answer Claude Code's permission questions from the Mac app: a panel above the office and notifications with Allow and Deny
- Answer permission questions on the iPhone too, in the app or from the notification. The command is end-to-end encrypted in iCloud
- The plugin records permission questions and finished tools, so a raised hand goes down as soon as the question is answered

### Changed
- The Mac app asks for the AgentOffice folder, with write access, to save answers. Choosing only the Events folder still works without approvals
- The floor list shows floors with people at work first and fades empty floors below them

## [1.0.0] - 2026-11-16

The first public release: a signed and notarized Mac app, and the Claude Code plugin.

### Added
- Release script that builds a Developer ID signed, notarized disk image
- Setup guide in the Mac app, shown on first launch and from the Help menu (#26)
- Claude Code plugin and marketplace that install the hook, so there is no settings file to edit (#25)
- 3D view on iPhone, with a zoom from the building into a floor and back on both apps (#21)
- 3D office floor built with RealityKit: rooms, furniture, work animations, drag to turn, pinch to zoom (#20)
- Building view with a 2D and 3D switch (#19)
- Floors follow renamed and deleted project folders (#18)
- English and Korean localization (#15)
- Resident team members who wait at their own desks (#14)
- iPhone companion app synced through CloudKit, with an offline notice (#13)
- Team members (subagents) in department uniforms (#12)
- Floor list, activity log and employee cards on the Mac (#11)
- Walking employees with status tags, routed around furniture (#10)
- Pixel-art office floor drawn with SpriteKit (#8)
- Resting sessions go to the break room (#7)
- Session list in the Mac app (#6)
- Event and session models (#5)
- Claude Code hook that records an allow-list of event fields (#4)

### Changed
- The hook script moved from `Hooks/` to `plugin/scripts/`, and `jq` no longer needs installing because macOS includes it
- Polished the Mac menu bar, break room and app icons (#16)

### Fixed
- The 2D office could keep showing the building after leaving a 3D floor, and the layout now starts faster (#22)
- Employees of the same role no longer share one spot in a crowded room (#21)
- The hook records the folder the session started in (#9)

[Unreleased]: https://github.com/YUJEONGLEEEEE/AgentOffice/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/YUJEONGLEEEEE/AgentOffice/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/YUJEONGLEEEEE/AgentOffice/releases/tag/v1.0.0
