# QuickPeek v1.1.0

QuickPeek v1.1.0 refreshes the menu bar interface and improves release reliability.

## Highlights

- Redesigned the tracker list, empty state, add-tracker flow, and settings screen using native macOS controls.
- Keeps QuickPeek as a menu bar-only app without an unnecessary Dock icon.
- Preserves manually arranged tracker order across app restarts.
- Redacts API credentials from request error logs.
- Removes an unused file-access entitlement.

## Distribution

- Ships as a hardened universal app for Apple silicon and Intel Macs.
- Uses an ad-hoc signature because the project does not have a paid Apple Developer Program membership.
- Includes a SHA-256 checksum alongside the release archive.
- Is not notarized, so macOS may require **Right-click > Open** or **Open Anyway** on first launch.
