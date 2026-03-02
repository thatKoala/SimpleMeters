## v0.1.0 — Welcome Release

Welcome to the first release of **SimpleMeters**.  
This launch is focused on one goal: a combat meter that stays out of the way — **simple, fast, and lightweight**.

### Added
- Core damage-only tracking for:
  - **Total** damage (session total)
  - **Fight** damage (current fight)
  - **Boss** damage snapshots (boss encounter views)
- Class-colored names for quick player recognition
- Pet damage is always merged with owner
- Clean, stock-feel panel UI with compact rows and proportional bars
- Quick panel workflows via `/smsm`, including bar and text panel creation
- Minimap button for easy access
- Boss kill history support for quick backtracking of encounter performance

### Focus: Lightweight + Fast
- Minimal parsing path with early filtering of combat events
- Throttled UI updates to reduce frame impact
- No external dependencies or heavy background systems
- No feature bloat: just reliable damage insight in a small footprint

### Implementation Notes
- Overkill damage is not counted, so totals reflect effective damage contribution
- DPS is calculated from measured fight window (start → fight end timing), not noisy per-frame guessing
- Designed for WoW Classic Era / TBC gameplay patterns with a calm, low-noise UI profile

Thank you for trying this out — feedback is very welcome as we continue refining the “simple but useful” approach.
