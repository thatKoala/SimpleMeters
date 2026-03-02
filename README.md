# SimpleMeters

**SimpleMeters is a lightweight, stock-style World of Warcraft damage meter for Classic Era/TBC that tracks party/raid damage in Total, Fight, and Boss views with a calm, minimal UI.**

SimpleMeters stays intentionally focused: just solid damage tracking, clean presentation, and low-impact performance.

## What It Does

SimpleMeters tracks damage contributions from your side of the fight and turns them into three practical views:

- **Total**: damage since you last reset
- **Fight**: damage for the current fight
- **Boss**: a damage snapshot for each boss encounter

It uses in-game combat data to rank top players/actors, color names by class, and show compact rows with proportional bars for quick visual comparison.

## How Damage Is Tracked (Simple + Accurate)

- It listens to combat events and adds up valid damage values from your group and yours.
- It includes pet damage by default, merged with owner.
- It ignores wasted extra damage from overkill, so the meter reflects **real damage contribution** rather than overflow.
- It keeps data sorted and clean so what you need is immediately visible.

## How DPS Is Calculated

DPS is calculated from each fight’s measured duration:

- Start time is when combat begins.
- End time is anchored to the last real damage moment, so waiting time after the last hit does not drag DPS down.
- If combat looks finished, the addon waits for out-of-combat confirmation; if that signal never comes, a safe timeout finalizes the fight cleanly.
- DPS = `damage ÷ fight duration`.

So DPS stays stable and accurate across normal pulls, pauses, and messy combat transitions.

## Why It’s Lightweight

- Minimal combat parsing and targeted filtering keep processing lean.
- UI updates are throttled, and idle ticking is guarded so background cost stays low when there is nothing to update.
- No external dependencies or heavy background systems.
- Designed for practical readability, not feature bloat.

## Features

- Class-colored actor names
- Total / Fight / Boss views in one lightweight addon
- Resizable, movable panels
- Multiple panel styles (bar / text panel variants)
- In-session reset and local settings persistence
- Quick access via minimap button

## Controls

- Type `/smsm` to open options
- Type `/smsm 1` to create a bar panel
- Type `/smsm 2` to create a text panel

## Community Feedback

Community feedback is welcome — if you use it and have ideas, share them so we can keep refining it.

Author: `paul@thatkoala.com`  
Discord: [https://discord.gg/R2rPMrBnpN](https://discord.gg/R2rPMrBnpN)

World of Warcraft is a trademark of Blizzard Entertainment.  
SimpleMeters is a fan-made addon and is not affiliated with Blizzard Entertainment.
