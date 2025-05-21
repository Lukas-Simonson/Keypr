//
//  Keyp.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/21/25.
//

import SwiftUI
import Combine

@MainActor @propertyWrapper
public struct Keyp<V: Codable & Sendable>: DynamicProperty {
    @State private var keypUpdater: KeypUpdater<V>
    
    public var wrappedValue: V {
        get { keypUpdater.storedValue }
        nonmutating set { keypUpdater.updateValue(newValue) }
    }
    
    public var projectedValue: Binding<V> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    init(
        _ store: Keypr,
        value: ReferenceWritableKeyPath<KeyprValues, V>,
        publisher: KeyPath<KeyprValues, AnyPublisher<V, Never>>
    ) {
        keypUpdater = KeypUpdater(store: store, valuePath: value, publisherPath: publisher)
    }
}

@Observable
private class KeypUpdater<V: Codable & Sendable> {
    private let store: Keypr
    private let valuePath: ReferenceWritableKeyPath<KeyprValues, V>
    private var cancellable: AnyCancellable?
    
    private(set) var storedValue: V
    
    init(
        store: Keypr,
        valuePath: ReferenceWritableKeyPath<KeyprValues, V>,
        publisherPath: KeyPath<KeyprValues, AnyPublisher<V, Never>>
    ) {
        self.store = store
        self.valuePath = valuePath
        self.storedValue = store.values[keyPath: valuePath]
        
        self.cancellable = store.values[keyPath: publisherPath]
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.storedValue = newValue
            }
    }
    
    func updateValue(_ value: V) { store.values[keyPath: valuePath] = value }
    
    deinit { cancellable?.cancel() }
}
