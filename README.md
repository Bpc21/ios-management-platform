# iOS Management Platform

## Summary
This repository is the iOS counterpart of the macOS management platform.  
The current scope is functional parity for the operational core, not visual parity.

Operational core on iOS:
- Gateway connection to the same backend
- Gateway-backed login and session restore
- Dashboard (presence and gateway state)
- Agents (role-filtered list and detail)
- Sessions (list, detail, reset, compact, delete)
- Chat (OpenClaw transport)
- Users management (for allowed roles)
- Connection settings (local/remote transport model)

Out of scope for this pass:
- macOS-only surfaces such as menu bar extras, Miniverse desktop integration, and desktop diagnostics panes

## Architecture Notes
- App: SwiftUI, Swift Package Manager executable target (`OpenClawManagementIOS`)
- Shared protocol/UI dependencies: `../shared/OpenClawKit`
- Auth model: gateway-backed (`auth.login`, `auth.session`, `users.*`)
- Gateway client identity: currently uses the same accepted gateway client id path as macOS (`openclaw-macos`) for compatibility with existing gateway schema constraints

## Navigation and Access
Primary iOS navigation is role-aware and intentionally reduced to core destinations.

- Admin: `Dashboard`, `Agents`, `Sessions`, `Chat`, `Users`, `Settings`
- Operator: `Dashboard`, `Agents`, `Sessions`, `Chat`
- Basic: `Dashboard`, `Agents`, `Sessions`

## Build and Test
```bash
cd /Users/bpc/Documents/GitHub/ios-management-platform
swift build
swift test
```

## Deploy to iPhone (Thin Path)
This repo is SwiftPM-first. The thinnest repeatable device path is through Xcode’s package workspace.

1. Open the package in Xcode:
   - `File` -> `Open...` -> select `/Users/bpc/Documents/GitHub/ios-management-platform/Package.swift`
2. Select the `OpenClawManagementIOS` scheme.
3. Set destination to your connected iPhone.
4. In `Signing & Capabilities`, choose your Apple Team for the generated app target.
5. Build and Run.

If Xcode asks to create signing artifacts, accept the prompts for your personal/team profile.

## Manual QA Checklist
- Connect in local mode and remote mode (`ws://`/`wss://`)
- Sign in with an existing gateway user
- Relaunch and confirm session restore
- Verify dashboard presence updates
- Verify agents list/detail loads from gateway
- Verify sessions list and actions (`reset`, `compact`, `delete`)
- Verify user CRUD/allowlist behavior with role restrictions
- Verify iPhone portrait usability and keyboard behavior in login/settings
