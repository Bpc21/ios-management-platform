# iOS Management Platform Design & Architecture

## Overview
This repository contains the iOS adaptation of the macOS Operator Management Platform. It is a native SwiftUI application designed for iPhone and iPad, connecting to an OpenClaw Gateway as an `operator`-role client.

## Aesthetic Direction: "The Executive Dashboard"
After brainstorming, we have committed to a highly professional, data-dense design aesthetic optimized for efficiency and clarity. 

### Core Principles
1. **Zero "OpenClaw" Branding in UI:** The interface is totally generic (e.g., "Gateway Manager").
2. **Professional & Data-Dense:** The app targets power users. We use structured cards, tight margins, and segmented controls to maximize vertical screen real estate for logs, agent statuses, and data tables.
3. **No Neon / No Spatial Features:** Glows, neon colors, and 3D spatial window tricks are banned.
4. **Clean Light / Dark Modes:** The UI must look spectacular in both pure white (Light Mode) and OLED Black (Dark Mode). Shadows are subtle in Light Mode, replaced by pure un-elevated contrast in Dark Mode.
5. **Categorized Typography:** We rely strictly on font weights (San Francisco) to establish hierarchy, using SF Mono for raw data (logs, IDs).

## Core Navigation
- **Top-Level Segmented Controls / Minimal Strip:** Instead of a bulky tab bar or hamburger menu, the primary navigation between features (Dashboard, Agents, Sessions, Settings) utilizes a clean swipeable top-nav or segmented control strip, allowing the content to span the full height of the device.

## Core Features to Port (from macOS MVP)
- **Local Auth:** Login screen / first-admin onboarding.
- **Dashboard:** Grid of key gateway stats.
- **Agents:** List of spawned agents + basic stat view.
- **Sessions:** List of active chats/sessions.
- **Settings:** Gateway connection configuration (URL, Token).

*(Further features like Cron, Nodes, Skills, and Tools can be ported in subsequent phases.)*
