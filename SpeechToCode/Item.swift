//
//  Item.swift
//  SpeechToCode
//
//  Created by Chris Beavis on 04/03/2025.
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
