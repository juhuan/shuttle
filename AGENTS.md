# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Project Overview

Shuttle is a macOS native status bar (menu bar) application written in Objective-C using Cocoa/AppKit. It surfaces quick SSH connections and arbitrary terminal commands in a nested menu, driven by a JSON config (`~/.shuttle.json`) plus optional hosts parsed from `~/.ssh/config`.

## Technology Stack

- **Objective-C** with **Cocoa/AppKit** (`.xib`, `.lproj` localization)
- **Xcode** project (`Shuttle.xcodeproj`), shared scheme `Shuttle`
- **ARC** enabled across all targets (no `-fno-objc-arc` exceptions)
- **Minimum deployment target: macOS 13.0 (Ventura)**
- **JSON** configuration
- **XCTest** unit-test target (`ShuttleTests`)

## Architecture

The former monolithic `AppDelegate` was split into three layers plus a value object:

### Config layer (`Shuttle/Config/`)
- `SHConfigSource` — resolves the JSON file path (`~/.shuttle.path`, `~/.shuttle.json`) and mtime-based change detection.
- `SHShuttleConfig` — parses/defaults the JSON root object (`terminal`, `default_theme`, `open_in`, `show_ssh_config_hosts`, `ignore`, `hosts`, ...).
- `SHSSHConfigParser` — parses `~/.ssh/config` hosts (aliases, `Include`, `# shuttle.name` metadata, `Clients/` path segments).

### Menu layer (`Shuttle/Menu/`)
- `SHMenuNode` — an in-memory menu tree node (directory vs leaf, ordering markers `[aaa]`, separator `[---]`, command metadata).
- `SHMenuBuilder` — builds the `NSMenu` from config + SSH hosts.

### Terminal layer (`Shuttle/Terminal/`)
- `SHTerminalCommand` — value object normalizing `theme`/`title`/`open_in` from global defaults.
- `SHTerminalBackend` — protocol (`dispatchCommand:error:`).
- `SHTerminalAppBackend` — Terminal.app via AppleScript (the only AppleScript path left).
- `SHITermBackend` — iTerm via the `iterm2://` URL scheme (no Apple Events).
- `SHGhosttyBackend` — Ghostty via its own `ghostty` CLI (no Apple Events).
- `SHVirtualBackend` — `screen -d -m` via `NSTask` (no window).

### Other components
- `SHLaunchAtLogin` — launch-at-login via `SMAppService.mainAppService` (replaces the deprecated `LSSharedFileList`).
- `AppDelegate` — menubar wiring, config watching, menu rebuild.
- `AboutWindowController` — about dialog.

## Development Commands

```bash
# Run unit tests (this is what CI runs)
xcodebuild test -project Shuttle.xcodeproj -scheme Shuttle -destination 'platform=macOS'

# Build Debug
xcodebuild -project Shuttle.xcodeproj -scheme Shuttle -configuration Debug build

# Build Release + DMG (optionally sign/notarize via env vars)
./build.sh
```

## Testing

`ShuttleTests/` contains XCTest targets (pure logic, no `TEST_HOST`):

- `SHSSHConfigParserTests` — host aliases, `Include` recursion, `# shuttle.name`, safe empty/missing files.
- `SHMenuBuilderTests` — sorting, `[aaa]`/`[---]` markers, leaf command fields, SSH injection rules.
- `SHConfigSourceTests` / `SHShuttleConfigTests` — path resolution, defaults, overrides.
- `SHTerminalCommandTests` — terminal-type / theme / title / open-in normalization.
- `SHMenuBuilderGoldenTests` — regression: builds a menu tree from `ShuttleTests/Fixtures/` and compares to a checked-in `golden.json`.

CI (`.github/workflows/objective-c-xcode.yml`) runs `xcodebuild test` on push/PR; tagged commits additionally sign, notarize, staple, and package a DMG.

## File Structure

```
Shuttle.xcodeproj/
Shuttle/
├── AppDelegate.h/m
├── AboutWindowController.h/m
├── main.m
├── SHLaunchAtLogin.h/m
├── Config/                # SHShuttleConfig, SHConfigSource, SHSSHConfigParser
├── Menu/                  # SHMenuNode, SHMenuBuilder
├── Terminal/              # SHTerminalCommand, SHTerminalBackend + 4 backends
├── apple-scpt/            # compiled Terminal AppleScript only (terminal-*.scpt)
├── shuttle.default.json   # default config template
├── Shuttle-Info.plist
├── Shuttle.entitlements
└── *.lproj/               # localization
ShuttleTests/              # XCTest target + Fixtures/ (golden menu fixture)
apple-scripts/terminal/    # AppleScript sources (Terminal only)
specs/                     # spec/plan/tasks/tests for the modernization
```

## Configuration Format

`~/.shuttle.json` (see `shuttle.default.json`) supports `terminal` (matched case-insensitively: `"Terminal.app"`, `"iTerm"`/`"iTerm2"`, or `"Ghostty.app"`; anything else defaults to Terminal), `default_theme`, `open_in` (`tab`/`new`/`current`/`virtual`, where `virtual` runs `screen -d -m` with no window), `launch_at_login`, `show_ssh_config_hosts`, and a nested `hosts` array with per-command `theme`/`title`/`inTerminal`. JSON remains 100% backward compatible.

## Special Considerations

- **Entitlements** (`Shuttle/Shuttle.entitlements`): Apple Events are granted for Terminal.app only. iTerm2 (URL scheme) and Ghostty (CLI) intentionally require no Apple Events permission.
- **Terminal dispatch**: only Terminal.app uses AppleScript; do not add AppleScript back for iTerm2/Ghostty.
- **Localization**: `.lproj` + `*.strings`; interface in `.xib`.