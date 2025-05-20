//
//  NetworkMonitorProtocol.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import Combine

/// Protocol for monitoring network connectivity
protocol NetworkMonitorProtocol: ObservableObject {
    /// Whether the device has an active network connection
    var isConnected: Bool { get }
}
