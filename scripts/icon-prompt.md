# App icon

- `icon-artwork-source.png` was generated with `google/gemini-3-pro-image` via OpenRouter on 2026-11-25 (one of four candidates, two Gemini and two GPT-5.4 Image).
- `mask-icon.py` crops it (keeps 86%) and masks it into the macOS icon grid (824 px tile, radius 185, in a 1024 canvas, soft shadow):
  `python3 scripts/mask-icon.py scripts/icon-artwork-source.png Resources/AppIcon-1024.png 0.86`
- `build.sh` turns `Resources/AppIcon-1024.png` into `AppIcon.icns` with `sips` + `iconutil`.

## Prompt

Square app icon artwork for a macOS menu bar Pomodoro timer app called Tomatimer. 1024x1024, full-bleed square canvas (the background must fill the entire square edge to edge; do NOT draw rounded corners, borders, or a device frame; I will mask it myself).
Subject: a single ripe glossy tomato that is also a kitchen countdown timer, centered, occupying about 70% of the canvas. The front of the tomato has a smooth recessed timer face: a soft cream dial with a crisp tomato-red pie wedge showing roughly 70% of the time remaining (wedge starts at 12 o'clock and runs clockwise), a small central hub, and fine minimal tick marks. Fresh green calyx leaves and a short stem on top.
Style: premium Apple macOS Big Sur / Sequoia app icon style. Soft studio lighting from the top-left, subtle specular highlight, gentle realistic depth and soft contact shadow, clean simple shapes, no clutter. Background: smooth warm gradient from deep charcoal-plum at the bottom to slightly lighter at the top, or a soft warm cream; must contrast with the red tomato.
Absolutely no text, no letters, no numbers, no watermark.
