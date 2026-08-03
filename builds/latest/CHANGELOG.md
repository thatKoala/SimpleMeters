# SimpleMeters Changelog

## v0.5 - Responsive Reset + Performance

v0.5 focuses on immediate UI behavior, more compact layouts, and lower overhead as combat history grows.

### Fixes

- Reset now clears Total, Fight, and Boss displays immediately without requiring a tab change.
- Fixes a roster-refresh error that could occur while loading existing saved combat data.
- Dungeon reset prompts recognize Blizzard's localized reset-success format, ignore zoning and unrelated messages, and appear only when meter data exists.
- Reset removes old actor and spell tables completely instead of retaining empty historical records.
- Boss history and selected snapshots clear immediately with the rest of the meter data.

### Layout

- Reduces the minimum panel width from 240px to 220px.
- Keeps enough room for the three bottom tabs, damage values, DPS values, and header controls at minimum width.

### Performance

- Periodic combat saves now copy only actors and spell metadata that changed since the previous save.
- Boss history is recopied only when boss history changes or a forced zoning/logout save is requested.
- Removes redundant ranking rebuilds during combat periods with no new damage.
- Removes unused formatting, animation, table, and GUID lookup bookkeeping code.

### Compatibility

- Classic Era and Season of Discovery interface `11508`.
- TBC Classic / Anniversary progression interfaces `20505` and `20506`.

### Build Integrity

- `SimpleMeters-v0.5.zip` SHA-256: `dac6c41ee256b31a2bb8323c53287135a0b72418d0cb0aed7164848767218eee`

## v0.41 - Combat Reliability + UI Polish

v0.41 focuses on combat reliability, cleaner attribution, safer persistence, and a more stock-feeling interface.

### Combat Reliability

- Saves combat data more safely during logout, zoning, and longer fights.
- Adds a periodic lightweight save during active fights when data is dirty.
- Improves source attribution for group members, mind-control-style flag weirdness, pets, and guardians.
- Rejects unowned NPC/object damage from player rankings to avoid misleading `Unknown` rows.
- Adds reactive shield damage handling, including Ret Aura and Thorns-style events.
- Handles Shadow Word: Death backlash/self-damage as friendly/self damage instead of outgoing DPS.

### UI Improvements

- Boss mode now keeps player rows in the main panel and shows boss history in an attached popout.
- Boss history shows up to five kills and supports scrolling for longer histories.
- Header controls were cleaned up into native-feeling icon buttons.
- Damage row borders now draw above the bar fill for a cleaner rounded-edge look.
- Row DPS text now uses `348/s` instead of `(348/s)`.
- Tooltips split player abilities, pet abilities, and pet totals.

### Commands

- `/smsm` and `/smsm help` show all commands.
- `/smsm show` shows all SimpleMeters panels.
- `/smsm hide` hides all SimpleMeters panels.
- `/smsm toggle` shows or hides available panels.
- `/smsm minimap` and `/smsm map` toggle the minimap button.

### Compatibility

- Classic Era and Season of Discovery interface `11508`.
- TBC Classic / Anniversary progression interfaces `20505` and `20506`.

### Build Integrity

- `SimpleMeters-v0.41.zip` SHA-256: `60542aa39041d4b5ddc78d4dffbadbcfd374ef618a5126bb556754273b31007a`

## v0.3 - Background Reliability

### Highlights

- Damage tracking now stays consistent in the background, even when panels are hidden or different panels are on different tabs.
- Total, Fight, and Boss views now read from the same live data flow, so switching tabs is visual-only and no longer unsticks values.
- Fight ending is more robust: damage timing freezes at the last real hit, and fights now have a safe finalize timeout if out-of-combat signals do not arrive.
- UI update flow is more efficient with an idle guard, so active ticking is reduced when there is no real work to do.

### Player-Facing Improvements

- Better reliability for Total updates in solo and party situations.
- Better consistency when running multiple panels at once.
- Lower risk of stale values when hiding/showing panels during combat.
- Smoother panel refresh behavior with less unnecessary background activity.

### Performance Notes

- The combat parser remains lightweight and damage-focused.
- Data prep and rendering are now separated to keep panel interactions responsive.
- Idle update behavior is optimized to reduce unnecessary work between fights.

### Build Integrity

- `SimpleMeters-v03p.zip` SHA-256: `db95347717b9ee1743f20f3eca12ed8ae092954c26e81b073d4765b871474ad3`

## v0.2 - Persistence + Background Updates

This release is all about smoother tracking and better reliability in everyday play.

- Damage totals now keep updating more consistently during combat, including when views are hidden.
- Panel clicks and tab changes are now visual-only, so the meter logic keeps running in the background.
- Data handling was cleaned up so Total, Fight, and Boss views all read from the same core tracking source.
- Persistence was improved so progress is better protected across crashes, `/reload`, and normal logout.
- General polish was applied to keep performance lightweight and reduce UI stutter.

### Build Integrity

- `SimpleMeters.zip` SHA-256: `f1d8031cf3bcdd5556d9d0b048fa7f0c8b4a45b3da5d4280f3073a5b88ee1bf0`

## v0.1 - Welcome Release

Welcome to the first release of SimpleMeters. This launch focused on one goal: a combat meter that stays out of the way: simple, fast, and lightweight.

### Added

- Core damage-only tracking for Total, Fight, and Boss views.
- Class-colored names for quick player recognition.
- Pet damage merged with owner.
- Clean, stock-feel panel UI with compact rows and proportional bars.
- Quick panel workflows via `/smsm`, including bar and text panel creation.
- Minimap button for easy access.
- Boss kill history support for quick backtracking of encounter performance.

### Focus: Lightweight + Fast

- Minimal parsing path with early filtering of combat events.
- Throttled UI updates to reduce frame impact.
- No external dependencies or heavy background systems.
- No feature bloat: just reliable damage insight in a small footprint.

### Implementation Notes

- Overkill damage is not counted, so totals reflect effective damage contribution.
- DPS is calculated from the measured fight window, not noisy per-frame guessing.
- Designed for WoW Classic Era / TBC gameplay patterns with a calm, low-noise UI profile.
