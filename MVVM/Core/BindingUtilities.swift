//
//  BindingUtilities.swift
//  Music Memory New
//
//  Created by Jacob Rees on 20/05/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Publisher for async operations

/// A publisher wrapper for async operations
struct AsyncOperation<Output, Failure: Error>: Publisher {
    typealias Output = Output
    typealias Failure = Failure
    
    private let operation: () async throws -> Output
    
    init(_ operation: @escaping () async throws -> Output) {
        self.operation = operation
    }
    
    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = AsyncSubscription(operation: operation, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
    
    private class AsyncSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {
        private var subscriber: S?
        private let operation: () async throws -> Output
        private var task: Task<Void, Never>?
        
        init(operation: @escaping () async throws -> Output, subscriber: S) {
            self.operation = operation
            self.subscriber = subscriber
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0, let subscriber = subscriber else { return }
            
            task = Task {
                do {
                    let result = try await operation()
                    _ = subscriber.receive(result)
                    subscriber.receive(completion: .finished)
                } catch {
                    subscriber.receive(completion: .failure(error as! Failure))
                }
            }
        }
        
        func cancel() {
            task?.cancel()
            subscriber = nil
        }
    }
}

// MARK: - Binding Extensions

extension Binding {
    /// Unwraps an optional binding to create a binding to the wrapped value
    func unwrap<Wrapped>() -> Binding<Wrapped>? where Value == Wrapped? {
        guard let value = wrappedValue else { return nil }
        
        return Binding<Wrapped>(
            get: { value },
            set: { wrappedValue = $0 }
        )
    }
    
    /// Creates a derived binding that applies a transform when setting the value
    func transform<T>(_ transform: @escaping (T) -> Value) -> Binding<T> {
        Binding<T>(
            get: { fatalError("Transform binding only supports setting values") },
            set: { self.wrappedValue = transform($0) }
        )
    }
    
    /// Creates a derived binding with different get and set transforms
    func bimap<T>(
        get: @escaping (Value) -> T,
        set: @escaping (T) -> Value
    ) -> Binding<T> {
        Binding<T>(
            get: { get(self.wrappedValue) },
            set: { self.wrappedValue = set($0) }
        )
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Suspends the current task for the given duration
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
