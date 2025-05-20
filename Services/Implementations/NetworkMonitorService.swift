//
//  NetworkMonitorService.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Network
import Foundation

/// Service for monitoring network connectivity
class NetworkMonitorService: ObservableObject, NetworkMonitorProtocol {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.jacobrees.MusicMemory.NetworkMonitor")
    
    @Published var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
