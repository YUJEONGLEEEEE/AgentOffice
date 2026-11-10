# Changelog

All notable changes to this project are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
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
- Polished the Mac menu bar, break room and app icons (#16)

### Fixed
- The 2D office could keep showing the building after leaving a 3D floor, and the layout now starts faster (#22)
- Employees of the same role no longer share one spot in a crowded room (#21)
- The hook records the folder the session started in (#9)
