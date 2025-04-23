//
//  Item.swift
//  myMoti
//
//  Created by Petros Dhespollari on 25/8/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
