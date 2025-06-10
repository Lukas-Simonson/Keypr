//
//  AsyncStateSequence.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

import Foundation

/// An async sequence that maintains and emits the latest value to subscribers.
/// Supports both immediate and async emission of new values.
/// Used internally by `Keypr` to produce a stream of value updates.
public final class AsyncStateSequence<Element: Sendable>: Sendable, AsyncSequence {
    
    /// The internal actor used for managing state and subscribers.
    private let state: State
    
    /// The current value of the sequence.
    var value: Element {
        get async { await state.value }
    }
    
    /// Initializes the sequence with an initial value.
    /// - Parameter initial: The initial value to store and emit.
    init(initial: Element) {
        self.state = State(initial: initial)
    }
    
    /// Emits a new value to all subscribers asynchronously.
    /// - Parameter element: The value to emit.
    func emit(_ element: Element) async {
        await state.emit(element)
    }
    
    /// Emits a new value to all subscribers, scheduling the emission on a new task.
    /// - Parameter element: The value to emit.
    func emit(_ element: Element) {
        Task { await state.emit(element) }
    }
    
    /// Returns an async iterator for the sequence.
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

extension AsyncStateSequence {
    
    /// An actor that manages the current value and subscriber continuations.
    actor State {
        
        /// The current value.
        private(set) var value: Element
        
        /// The list of continuations waiting for the next value.
        private var subscribers: [CheckedContinuation<Element, Never>] = []
        
        /// Initializes with an initial value.
        /// - Parameter initial: The initial value.
        init(initial: Element) {
            self.value = initial
        }
        
        /// Emits a new value and resumes all waiting subscribers.
        /// - Parameter newValue: the value to emit
        func emit(_ newValue: Element) {
            value = newValue
            
            let subs = subscribers
            subscribers.removeAll()
            
            for sub in subs {
                sub.resume(returning: value)
            }
        }
        
        /// Suspends until the next value is emitted, then returns it.
        /// - Returns the next emitted value.
        func suspendUntilNextValue() async -> Element {
            await withCheckedContinuation { cont in
                subscribers.append(cont)
            }
        }
    }
}

extension AsyncStateSequence {
    
    /// An async iterator that yields the current value and then waits for subsequent emissions.
    public struct Subscription: Sendable, AsyncIteratorProtocol {
        
        /// The state actor to observe.
        private let state: State
        
        /// The last value emitted.
        private var value: Element!
        
        /// Whether the first value has been emitted.
        private var firstEmitted: Bool = false
        
        
        /// Initializes the subscription with a state actor.
        /// - Parameter state: The state to observe.
        init(state: State) {
            self.state = state
        }
        
        /// Returns the next value in the sequence, suspending until a new value is available.
        public mutating func next() async -> Element? {
            if !firstEmitted {
                value = await state.value
                firstEmitted = true
                return value
            }
            
            return await state.suspendUntilNextValue()
        }
    }
}
