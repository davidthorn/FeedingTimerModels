# Average Duration Calculations

This note summarizes how Average Duration is computed and enhanced to reflect a baby’s evolving patterns.

## What counts as “feeding time”
- Average Duration uses only `breastUnits` on each `FeedingLogEntry`.
- A feed’s duration = sum of its units’ durations. Entries without units are excluded from Average Duration calculations.
- Start/end timestamps remain useful for session envelopes and other stats, but not for Average Duration.

## Windows and scenarios
- Windows: `.days(n)` uses civil-day boundaries; `.hours(n)` is a rolling window ending at `now`.
- Scenarios: `.all`, `.day`, `.night` filter feeds before averaging; time-of-day grouping uses the entry’s start slot.

## Outliers
- Optional IQR filtering removes extremes before averaging.
- Filtering is done by bounds (Q1−1.5·IQR, Q3+1.5·IQR) so sample timestamps are preserved.

## Recency weighting (optional)
- To “learn” from recent behavior, an exponentially weighted moving average (EWMA) is available.
- Weight per sample: `exp(-ageSeconds / tau)`, where `tau = halfLifeHours / ln(2) * 3600`.
- Pass `recencyHalfLifeHours` to favor recent feeds; omit it to keep equal weights.

## Grouping behavior
- None: Average across feeds (units-only).
- Breast: For each feed, compute Left/Right unit sums independently; average per side across feeds (units-only).
- Time of day: Bucket by a feed’s start slot; average per slot (units-only).

## Backward compatibility
- If `recencyHalfLifeHours` is not provided, results match prior arithmetic-mean behavior except that entries lacking units are now excluded (not envelope-fallback).

