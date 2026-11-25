# Tomatimer — design (2026-11-25)

## Intent
A Pomodoro timer in the macOS menu bar for a MacBook Pro (M5). Light on CPU and memory, clean to look at, and built to pull the user back to work after a distraction. App blocking comes later.

## Goals
- Menu bar item: coloured progress ring + mm:ss countdown (red focus, green break, blue long break, grey paused).
- Popover: large ring, "What are you working on?" intention field, start/pause, skip, reset, today's session dots, inline settings.
- End of each phase: translucent full-screen overlay on every display with a chime. Click (or Return) to continue.
- Away detection: no keyboard/mouse input for 3+ min during focus (or the Mac slept) → on return, a card: "Away 7 min. Resume <intention>?"
- Drift reminder: in an active session, if no timer runs for 5 min (after a break, or while paused), the menu bar item pulses and a reminder card appears every 5 min until a timer starts or the user picks "Done for today".
- Global hotkey ⌃⌥P to start/pause (Carbon hotkey, no permissions needed).
- Launch at login toggle (SMAppService).

## Non-goals (v1)
App blocking, history/stats, sync, notch UI, App Store distribution.

## Constraints
- The user has no Xcode. The VPS runs Linux, so it cannot compile AppKit.
- Not signed with an Apple Developer ID. The app is ad-hoc signed.

## Approaches considered
1. Command Line Tools on the Mac + local build script. Lightest setup, but needs a 1–2 GB install on the user's Mac.
2. **GitHub Actions macOS runner builds the app; user downloads a release zip (chosen).** Nothing to install on the Mac, gives a public download link, and the VPS can push changes.
3. JavaScript for Automation + `osacompile`. No compiler needed, but weak UI and no path to app blocking.

## Build decisions (builder's calls)
- Swift 5 language mode, AppKit + SwiftUI, compiled with `swiftc` directly. No Xcode project or SPM; `build.sh` assembles the `.app` bundle.
- Universal binary (arm64 + x86_64), minimum macOS 13.
- `LSUIElement` = true (no Dock icon).
- Ticks run only while a timer is running (1 Hz, with timer tolerance). Remaining time is derived from an end date, so the countdown survives sleep.
- App icon drawn by a Swift script in CI and converted with `iconutil`.
- `install.sh` downloads with curl. curl does not set the quarantine flag; `xattr -cr` runs anyway as a safeguard.
