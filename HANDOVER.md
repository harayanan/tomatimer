# Tomatimer — Handover

## Status
v1 written and pushed. Builds on GitHub Actions; the user installs via `install.sh`.

## Session 2026-11-25
- Agreed scope with the user: menu bar item (not notch), very visible prompts, help returning after distraction. App blocking deferred.
- Build path chosen: GitHub Actions macOS runner (the user has no Xcode; dev box is a Linux VPS).
- Built: timer engine, menu bar ring/countdown, popover with intention field + settings, full-screen phase-end overlay, away-return card, drift reminders with pulsing ring, ⌃⌥P hotkey, launch at login, generated app icon.

## Session 2026-11-25 (round 2: polish)
- User confirmed v1 installed and working.
- Left-click on the menu bar item starts/pauses/resumes; right-click (or ⌥-click) opens the panel (user's explicit spec).
- Menu bar glyph is now a shrinking pie; template glyphs for paused (bars) and idle (tomato outline).
- Panel redesigned: 196 pt dial (ticks, gradient arc, knob, click to toggle), "until hh:mm", phase chip, grouped settings.
- Prompts: entrance spring, pulsing halo, faint dial motif behind full-screen prompts.
- New app icon: Gemini 3 Pro Image via OpenRouter (user preference: use image models for artwork), masked to the macOS grid.
- Added `--snapshot` mode + CI artifact for design review; `polish/**` branches build without releasing.

## Next steps
- User to install and give feedback on look and nudges.
- App blocking (next feature the user named).
- Possible: history/stats, custom hotkey, notch UI.

Last reviewed: 2026-11-25
