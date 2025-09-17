//
//  Model+extensions.swift
//  Models
//
//  Created by David Thorn on 17.09.25.
//

import Foundation

public extension Calendar {
    func timeOfDaySlot(for date: Date) -> TimeOfDaySlot {
        let h = component(.hour, from: date)
        switch h {
        case 0..<6:  return .night
        case 6..<12: return .morning
        case 12..<18:return .afternoon
        default:     return .evening
        }
    }
    
    func timeOfDayBucketSlot(for date: Date) -> TimeOfDayBucket.Slot {
        let h = component(.hour, from: date)
        switch h {
        case 0..<6:  return .night
        case 6..<12: return .morning
        case 12..<18:return .afternoon
        default:     return .evening
        }
    }
}

public extension Array where Element == TimeOfDayBucket {
    func sortedByCurrentTimeSlot() -> [TimeOfDayBucket] {
        guard !self.isEmpty else { return self }
        
        let calendar = Calendar.current
        let currentSlot = calendar.timeOfDayBucketSlot(for: .now)
        
        let order: [TimeOfDayBucket.Slot] = [.morning, .afternoon, .evening, .night]
        
        guard let startIndex = order.firstIndex(of: currentSlot) else { return self }
        
        // Build rotated order going backwards in time
        var rotated: [TimeOfDayBucket.Slot] = []
        for offset in 0..<order.count {
            let idx = (startIndex - offset + order.count) % order.count
            rotated.append(order[idx])
        }
        
        let indexMap = Dictionary(uniqueKeysWithValues: rotated.enumerated().map { ($1, $0) })
        
        return self.sorted {
            guard
                let idx1 = indexMap[$0.id],
                let idx2 = indexMap[$1.id]
            else { return false }
            return idx1 < idx2
        }
    }
}
