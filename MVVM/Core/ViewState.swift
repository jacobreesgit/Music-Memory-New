//
//  ViewState.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation

/// Represents the different states a view can be in
enum ViewState<Content, Error: Swift.Error> {
    case loading
    case content(Content)
    case error(Error)
    
    /// Whether the state is loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    /// The content if available, nil otherwise
    var content: Content? {
        if case .content(let content) = self {
            return content
        }
        return nil
    }
    
    /// The error if available, nil otherwise
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
    
    /// Maps the content to a new type using the provided transform
    func mapContent<T>(_ transform: (Content) -> T) -> ViewState<T, Error> {
        switch self {
        case .loading:
            return .loading
        case .content(let content):
            return .content(transform(content))
        case .error(let error):
            return .error(error)
        }
    }
}
