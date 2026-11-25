# Tomatimer

A small Pomodoro timer for the macOS menu bar. Native Swift, about 1 MB, uses no CPU while idle.

## Install

Paste into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/harayanan/tomatimer/main/install.sh | bash
```

The command downloads the latest build, puts it in `/Applications`, clears the macOS quarantine flag and launches it. Run it again to update.

Manual install: download `Tomatimer.zip` from [Releases](https://github.com/harayanan/tomatimer/releases/latest), unzip, move to Applications, then run `xattr -cr /Applications/Tomatimer.app` once. The app is ad-hoc signed and not notarised, so Gatekeeper blocks it until the flag is cleared.

## What it does

- **Menu bar:** a coloured ring and countdown. Red = focus, green = break, blue = long break, grey = paused.
- **Click the ring:** large timer, a "What are you working on?" field, start/pause, skip, reset, today's sessions and settings.
- **End of each phase:** a full-screen overlay on every display with a chime. Return = primary action, Esc = secondary.
- **Away detection:** no keyboard/mouse input for 3+ minutes during focus (or the Mac slept). On your return you get a card with what you were working on and the time left.
- **Drift reminder:** once a session has started, if no timer runs for 5 minutes, the ring pulses amber and a reminder card appears every 5 minutes until you start a timer or choose "Done for today".
- **Hotkey:** ⌃⌥P starts and pauses from anywhere.
- **Launch at login:** toggle in settings.

Defaults: 25 / 5 / 15 minutes, long break every 4 blocks. All are adjustable in settings.

## Build

The app is built by GitHub Actions on every push to `main` (`.github/workflows/build.yml`), producing a release with `Tomatimer.zip`. To build locally on a Mac with Command Line Tools: `./build.sh` → `build/Tomatimer.app`.
