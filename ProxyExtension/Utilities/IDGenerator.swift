//
//  IDGenerator.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 08/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation

// Generates a unique id every time generate() is called
// Will wrap around when it reaches UInt64.max (at the end of the universe)
struct IDGenerator {
    typealias ID = UInt64
    var nextID: ID = 0

    mutating func generate() -> ID {
        nextID &+= 1 // Wrap around behaviour
        return nextID
    }
}
