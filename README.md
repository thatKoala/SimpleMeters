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

## v0.4 Patch Notes

v0.4 is a lightweight reliability and UI polish release focused on keeping SimpleMeters dependable during real dungeon and raid play.

- Combat data is saved more safely during logout, zoning, and longer fights.
- Damage attribution is stricter for group members, pets, guardians, reactive damage, and self-damage edge cases.
- Boss mode keeps player rows in the main meter and shows boss history in a fixed attached popout.
- Row DPS text uses `348/s` formatting instead of `(348/s)`.
- Tooltips separate player abilities, pet abilities, and pet totals.
- Slash commands now include explicit show, hide, toggle, and minimap controls.
- Header controls and damage rows were polished for a cleaner stock-UI feel.
- Damage row borders now draw over the bar fill, improving the rounded-edge look.
- TOC compatibility is prepared for Classic Era / Season of Discovery interface `11508` and TBC Classic interfaces `20505` and `20506`.

Release integrity:

- `SimpleMeters-v0.4.zip` SHA-256: `e498ee32982aac522c484a993e66fb4fc5600ad6dc5fa9ac98033c53eb5059dd`

Author: `paul@thatkoala.com`

