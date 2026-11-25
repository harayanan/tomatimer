# Tomatimer

macOS menu bar Pomodoro timer. Swift 5 mode, AppKit + SwiftUI, compiled with `swiftc` (no Xcode project, no SPM).

- Development happens on a Linux VPS. It cannot compile AppKit, so **GitHub Actions is the compiler**: push to `main` → `macos-15` runner → `build.sh` → release `v1.0.<run>` with `Tomatimer.zip`.
- Check builds with `gh run list -R harayanan/tomatimer` / `gh run view <id> --log-failed`.
- User installs/updates with `install.sh` (curl → /Applications → xattr -cr → open).
- Min macOS 13 (SMAppService). Universal binary. `LSUIElement` (no Dock icon).

## Layout
- `Sources/App.swift` — entry point, AppDelegate, wiring, prompt copy (phase end, away, drift).
- `Sources/TimerEngine.swift` — state machine (phase, run state, end-date based countdown, daily count).
- `Sources/Settings.swift` — UserDefaults-backed prefs, `Phase`/`RunState` enums.
- `Sources/StatusItemController.swift` — menu bar ring + countdown, popover, drift pulse.
- `Sources/PopoverView.swift` — SwiftUI popover and settings.
- `Sources/Overlay.swift` — full-screen overlay and card windows.
- `Sources/AttentionMonitor.swift` — away detection (CGEventSource idle time, sleep gaps) and drift reminders.
- `Sources/HotKey.swift` — Carbon global hotkey (⌃⌥P).
- `scripts/make-icon.swift` — draws the app icon at build time.

## Conventions
- All UI classes are `@MainActor`. Timers use target/selector (not closures) to avoid Sendable-closure isolation errors.
- Ticks run only while a timer runs. Keep idle CPU at zero.
- Planned: app blocking (NSWorkspace frontmost-app observer, plugs into AttentionMonitor).
