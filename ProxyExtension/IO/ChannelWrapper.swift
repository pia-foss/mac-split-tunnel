//
//  Channel+Extension.swift
//  SplitTunnelProxy
//
//  Created by John Mair on 15/01/2024.
//  Copyright © 2024 PIA. All rights reserved.
//

import Foundation
import NIO
import NIOPosix

// Force NIO Channel to conform to our simplified SessionChannel protocol
extension NIO.Channel: SessionChannel {}
extension NIO.DatagramChannel: SessionChannel {}

