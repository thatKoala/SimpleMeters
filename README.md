# SimpleMeters

SimpleMeters is a lightweight, stock-style damage meter for WoW Classic Era/TBC.

It focuses on clear, fast damage tracking with minimal UI overhead.

## Project Scope

- Damage-only meter (no healing/HPS scope)
- Modes: `Total`, `Fight`, `Boss`
- Class-colored rows and compact stock-UI presentation
- Multi-panel support (bar panel and text panel)
- Local persistence for totals and boss history
- Pet merge support

## Commands

- `/smsm` toggles all panels
- `/smsm 1` creates a new bar panel
- `/smsm 2` creates a new text panel
- `/smsm help` shows command help

## Design Goals

- Keep combat parsing lightweight
- Keep UI updates throttled and smooth
- Stay strictly stock Blizzard style/assets
- Stay compatible with Classic Era and TBC clients

Author: `paul@thatkoala.com`
