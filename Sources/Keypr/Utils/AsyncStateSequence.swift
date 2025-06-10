//
//  AsyncStateSequence.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

import Foundation

public final class AsyncStateSequence<Element: Sendable>: Sendable, AsyncSequence {
    
    private let state: State
    
    var value: Element {
        get async { await state.value }
    }
    
    init(initial: Element) {
        self.state = State(initial: initial)
    }
    
    func emit(_ element: Element) async {
        await state.emit(element)
    }
    
    func emit(_ element: Element) {
        Task { await state.emit(element) }
    }
    
    public func makeAsyncIterator() -> Subscription {
        Subscription(state: state)
    }
}

extension AsyncStateSequence {
    actor State {
        private(set) var value: Element
        private var subscribers: [CheckedContinuation<Element, Never>] = []
        
        init(initial: Element) {
            self.value = initial
        }
        
        func emit(_ newValue: Element) {
            value = newValue
            
            let subs = subscribers
            subscribers.removeAll()
            
            for sub in subs {
                sub.resume(returning: value)
            }
        }
        
        func suspendUntilNextValue() async -> Element {
            await withCheckedContinuation { cont in
                subscribers.append(cont)
            }
        }
    }
}

extension AsyncStateSequence {
    public struct Subscription: Sendable, AsyncIteratorProtocol {
        private let state: State
        private var value: Element!
        private var firstEmitted: Bool = false
        
        init(state: State) {
            self.state = state
        }
        
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
