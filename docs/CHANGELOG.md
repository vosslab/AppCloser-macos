# Changelog

## 2026-02-27

### Fixes and Maintenance
- Handle AppleScript error -600 ("Application isn't running") gracefully instead of printing raw error dict
- Pre-check if app is still running before sending quit AppleScript to skip apps that already quit
- Both changes fix a harmless race condition where an app quits between loading the list and sending the quit command

## 2026-02-26

### Additions and New Features
- Added "Check All" button alongside existing "Uncheck All" for quick bulk selection
- Added color-coded row backgrounds: red/pink for apps marked to close, green for safe/kept apps
- Added live "N apps selected" counter near the bottom of the window
- Added confirmation dialog before closing apps ("Close N apps?" with Cancel/Close)

### Behavior or Interface Changes
- Toggling "Include menu bar / accessory apps" now immediately refreshes the app list (no manual refresh needed)
- "Close Selected Apps" button is now disabled when no apps are selected
- Replaced non-ASCII emoji in debug output (`[x]`/`[ ]` instead of checkmark/square emoji)

### Fixes and Maintenance
- Refactored `loadApps()` into `getRunningApps()` and `toAppInfo()` subfunctions
- Extracted view body into computed subview properties: `toolbarButtons`, `appRow()`, `appList`, `statusSection`, `actionButtons`, and `beginClosing()` to reduce nesting and improve readability
- Replaced non-ASCII emoji with ASCII text in `README.md` and `build_release.sh`
- Disabled macOS window state restoration so the window always opens at 800x600
- Window opens at 800x600 via `NSWindow.setContentSize` but remains resizable
