# App Branding & Terminology Constraints

## CRITICAL: NO OPENCLAW BRANDING

The user has explicitly mandated that the iOS application **must absolutely not contain any reference to "OpenClaw"** in its user interface, naming, or visible copy. 

While the app connects to and interacts with an OpenClaw Gateway on the backend as an operator client, the user interface should be completely agnostic of this branding.

### Guidelines for Agents touching this repository:
1. **App Name:** Do not use "OpenClaw" or "OpenClaw Management" as the display name. Use generic terms like "Gateway Manager", "Management Console", or simply "Dashboard" (we will clarify the exact Display Name with the user later).
2. **Dashboard Text:** Never write "Connected to OpenClaw" or "OpenClaw Agents". Use "Connected to Gateway", "Active Agents", etc.
3. **Settings/Config:** "OpenClaw Config" should be "Gateway Settings", "Server Config", etc.
4. **Codebase/Documentation:** You may refer to the OpenClaw API or Gateway in comments, variable names, and documentation (like this file) so the context is preserved for developers/agents, but strings displayed to the user (`Text()`, `Label()`, `String` localized files) MUST NOT contain "OpenClaw".
