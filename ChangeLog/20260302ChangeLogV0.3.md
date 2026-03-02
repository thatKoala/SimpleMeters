# SimpleMeters v0.3

## Highlights

- Damage tracking now stays consistent in the background, even when panels are hidden or different panels are on different tabs.
- Total, Fight, and Boss views now read from the same live data flow, so switching tabs is visual-only and no longer "unsticks" values.
- Fight ending is more robust: damage timing freezes at the last real hit, and fights now have a safe finalize timeout if out-of-combat signals do not arrive.
- UI update flow is more efficient with an idle guard, so active ticking is reduced when there is no real work to do.

## Player-Facing Improvements

- Better reliability for Total updates in solo and party situations.
- Better consistency when running multiple panels at once.
- Lower risk of stale values when hiding/showing panels during combat.
- Smoother panel refresh behavior with less unnecessary background activity.

## Performance Notes

- The combat parser remains lightweight and damage-focused.
- Data prep and rendering are now separated to keep panel interactions responsive.
- Idle update behavior is optimized to reduce unnecessary work between fights.

## Next Version Backlog (v0.4)

- Full cleanup of legacy dirty-flag compatibility paths.
- Additional cache and hidden-panel optimization audit.
- Optional advanced fight segmentation heuristics for long CC/immunity gaps.
- Optional lightweight debug telemetry for field profiling.

## Build Integrity

- `SimpleMeters-v03p.zip` SHA-256: `d643dac31f95b33111be348219f1a5f460763fdc56beb45254bbf51e85f9fdfb`
