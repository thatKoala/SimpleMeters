# SimpleMeters

SimpleMeters is a lightweight, stock-style damage meter for WoW Classic Era and TBC Classic.

It is built to stay fast and readable during real dungeon and raid play: clean panel options, focused damage metrics, and low-overhead updates that do not get in the way of gameplay.

## Project Overview

SimpleMeters tracks damage in three practical modes:

- `Total`: cumulative damage since last reset
- `Fight`: current encounter damage
- `Boss`: saved boss-fight snapshots for quick review

The addon supports two visual styles so you can choose what fits your UI layout:

- **Bar panel** for compact visual comparison
- **Text-only panel** for minimal footprint and quick scanning

## Why It Is Lightweight

- Damage-only scope keeps parsing and rendering focused.
- Combat updates are filtered and throttled to avoid noisy UI churn.
- Rendering is kept compact and stock-UI aligned, with no external libraries or heavy visual systems.
- Data is prepared once and reused across panels, which helps maintain smooth behavior in combat.

## DPS Integrity

SimpleMeters is designed so DPS remains practical and stable:

- Overkill is excluded from effective damage totals.
- Fight timing ends on fight-finish logic instead of continuing to drift after the real damage window.
- Total/Fight/Boss views all follow the same core timing principles so numbers remain consistent.

## Commands

- `/smsm` toggles all panels
- `/smsm 1` creates a new bar panel
- `/smsm 2` creates a new text panel
- `/smsm help` shows command help

## Compatibility

- Classic Era (`1.14.x` branch)
- Burning Crusade Classic (`2.5.x`, interface `20505`)

Author: `paul@thatkoala.com`

## Latest Build

- `SimpleMeters-v03p.zip -> db95347717b9ee1743f20f3eca12ed8ae092954c26e81b073d4765b871474ad3`

