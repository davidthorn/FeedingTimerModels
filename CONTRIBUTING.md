# Contributing (Short)

- Scope: Keep `Models` pure (data types/utilities) and `Statistics` as stateless services over `Models`.
- Style: Prefer small, focused structs/enums; add `Codable`, `Equatable`, `Sendable` where appropriate.
- Time/Calendar: For stats, accept `now` and `calendar` params or use `StatsEnvironment` so behavior is deterministic.
- Windows/Scenarios: Reuse `TimeWindow` and `AverageDurationScenario` rather than inventing new flags.
- Outliers: Reuse `OutlierService` (IQR) or its winsorization when averaging intervals/durations.
- Segment-aware: Where `FeedingLogEntry.breastUnits` exist, operate on segments; otherwise, use envelope start/end.
- Tests: Prefer pure functions; inject `NowProvider` and `Calendar` for predictability. Run with `swift test`.
- Docs: If you add a new service, add a brief note to `AGENTS.md` and a small snippet in `USAGE.md` if it’s user-facing.

## Quick Dev

```bash
swift build
swift test
```

## Where to Add Things

- New data type? Put it under `Sources/Models/**`.
- New stat or aggregation? Put it under `Sources/Statistics/Services/**`, wired through `FeedingStatsService` if it’s part of the public façade.

