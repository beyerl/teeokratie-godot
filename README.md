# Teeokratie – Godot port

A native **Godot 4.3** rebuild of the *Office* room from *Teeokratie*, a 2D
point-and-click adventure originally built in Unity on the Adventure Creator
framework. This is a scoped proof-of-concept: one room, rebuilt from scratch in
Godot (the Unity game has no automated port path — its content lives in Unity
scenes and Adventure Creator ActionLists, not in code).

**Play it:** https://beyerl.github.io/teeokratie-godot/

## What's implemented

- Real hand-drawn `Office` background and original character sprite sheets
- **Teesa** (player): 6-frame walk cycle, directional flip, click-to-move
- **Don Kamille** (NPC): idle + talking animation
- Room hotspots — Fenster, Bücherregal, Durchgangsklappvorrichtung, Prüfungsordnung
- A branching **dialogue tree** with selectable options and an objective, mirroring
  Adventure Creator's `ActionDialogOption` / `ActionObjectiveSet`. All German lines
  are taken from the original Unity scene.

## Controls

- **Click** the floor to walk; click a hotspot to walk over and look at it
- Click **Don Kamille** to start a conversation
- In dialogue: click an option, or click / press **Space** to advance

## Build locally

Requires Godot 4.3 (standard, not .NET).

```bash
# Web (HTML5/WASM) export -> build/
godot --headless --path . --import
godot --headless --path . --export-release "Web" build/index.html

# then serve build/ over HTTP (single-threaded build, no special headers needed)
python3 -m http.server 8099 --directory build
```

Open the editor with `godot --path .` to run it natively.

## Deployment

Pushes to `main` trigger `.github/workflows/deploy.yml`, which downloads a pinned
Godot 4.3 headless binary + export templates, exports the Web build, and publishes
it to GitHub Pages.
