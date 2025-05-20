//
//  BaseViewModel.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import Combine

/// Base protocol for all ViewModels in the application
protocol BaseViewModel: ObservableObject {
    associatedtype State
    
    var state: State { get }
    
    /// Initialize the ViewModel with any required setup
    func initialize()
    
    /// Clean up resources when the ViewModel is no longer needed
    func cleanup()
}

/// Default implementations for BaseViewModel
extension BaseViewModel {
    func initialize() {
        // Default empty implementation
    }
    
    func cleanup() {
        // Default empty implementation
    }
}
