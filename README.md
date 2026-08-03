# SimpleMeters

SimpleMeters is a lightweight, stock-style damage meter for WoW Classic Era, Season of Discovery, and TBC Classic.

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

- `/smsm` or `/smsm help` shows all commands available
- `/smsm show` shows all SimpleMeters panels
- `/smsm hide` hides all SimpleMeters panels
- `/smsm toggle` shows or hides the available SimpleMeters panels
- `/smsm 1` creates a new bar panel
- `/smsm 2` creates a new text panel
- `/smsm minimap` or `/smsm map` toggles the minimap button

## Compatibility

- Classic Era and Season of Discovery (`1.15.8`, interface `11508`)
- Burning Crusade Classic / Anniversary progression (`2.5.x`, interfaces `20505` and `20506`)

## v0.5 Patch Notes

v0.5 focuses on responsive resets, a more flexible compact layout, and smoother long-session performance.

- Reset now clears Total, Fight, and Boss displays immediately without requiring a tab change.
- Roster refresh no longer errors when loading existing saved combat data.
- Dungeon reset prompts now use Blizzard's localized reset-success format and require existing meter data and a stable world state.
- Reset fully discards old actor and spell tables, reducing stale-data overhead in long sessions.
- The minimum panel width is reduced from 240px to 220px while preserving safe spacing for tabs, rows, and header controls.
- Periodic combat persistence now updates only changed actors and spell metadata.
- Unchanged boss history is no longer rebuilt every five seconds during combat.
- Quiet combat periods avoid redundant ranking rebuilds while fight timeout and persistence checks remain active.
- Unused UI and lookup code was removed as part of a focused maintenance pass.

Release integrity:

- [Download SimpleMeters v0.5](builds/latest/SimpleMeters-v0.5.zip)
- `SimpleMeters-v0.5.zip` SHA-256: `dac6c41ee256b31a2bb8323c53287135a0b72418d0cb0aed7164848767218eee`

Author: `paul@thatkoala.com`

