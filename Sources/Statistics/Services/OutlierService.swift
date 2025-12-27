//
//  OutlierService.swift
//  FeedingTimer
//
//  Scaffolding for outlier handling and age-aware bounds.
//

import Foundation

public struct OutlierService: Sendable {
    public  let env: StatsEnvironment

    public init(env: StatsEnvironment = .init()) {
        self.env = env
    }

    // Drop values outside IQR whiskers (Q1-1.5*IQR, Q3+1.5*IQR)
    public func excludeIQR(_ values: [TimeInterval]) -> [TimeInterval] {
        guard values.count >= 4 else { return values }
        let sorted = values.sorted()
        func q(_ p: Double) -> TimeInterval {
            let x = max(0, min(Double(sorted.count - 1), p * Double(sorted.count - 1)))
            let lo = Int(floor(x)), hi = Int(ceil(x))
            if lo == hi { return sorted[lo] }
            let w = x - Double(lo)
            return sorted[lo] * (1 - w) + sorted[hi] * w
        }
        let q1 = q(0.25), q3 = q(0.75), iqr = q3 - q1
        let low = q1 - 1.5 * iqr, high = q3 + 1.5 * iqr
        return sorted.filter { $0 >= low && $0 <= high }
    }

    // Winsorize by dropping below a lower bound and capping above an upper bound
    public func winsorizeIntervals(_ intervals: [TimeInterval], ageDays: Int?) -> (values: [TimeInterval], capped: Int) {
        let sorted = intervals.sorted()
        let n = sorted.count

        @inline(__always)
        func percentile(_ p: Double) -> TimeInterval {
            let pos = Double(n - 1) * p
            let lo = Int(pos)
            let hi = min(lo + 1, n - 1)
            let w  = pos - Double(lo)
            return sorted[lo] + (sorted[hi] - sorted[lo]) * w
        }

        let q1  = percentile(0.25)
        let q3  = percentile(0.75)
        let iqr = q3 - q1

        let hardLower: TimeInterval = 120
        let hardUpper: TimeInterval = ageAwareUpperBound(ageDays: ageDays)

        let lowerBound = max(q1 - 1.5 * iqr, hardLower)
        let upperBound = min(q3 + 1.5 * iqr, hardUpper)

        guard lowerBound <= upperBound else { return ([], intervals.count) }

        let eps: TimeInterval = 0.5

        var capped = 0
        var kept: [TimeInterval] = []
        kept.reserveCapacity(intervals.count)

        for v in intervals {
            if v < lowerBound - eps {
                capped += 1
                continue
            }
            if v > upperBound + eps {
                capped += 1
                kept.append(upperBound)
            } else {
                kept.append(v)
            }
        }

        return (kept, capped)
    }

    public func ageAwareUpperBound(ageDays: Int?) -> TimeInterval {
        guard let ageDays else { return 43_200 }
        switch ageDays {
        case ..<28:   return 21_600
        case 28..<90: return 28_800
        case 90..<182:return 36_000
        default:      return 43_200
        }
    }

    public func ageAwareUpperBound(birthDate: Date, now: Date? = nil) -> TimeInterval {
        let cal = env.calendar
        let anchor = now ?? env.nowProvider.now
        let months = cal.dateComponents([.month], from: birthDate, to: anchor).month ?? 0
        switch months {
        case ..<1:   return 21_600
        case 1..<3:  return 28_800
        case 3..<6:  return 36_000
        default:     return 43_200
        }
    }
}
