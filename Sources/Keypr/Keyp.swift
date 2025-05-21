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
        keypUpdater = PathKeypUpdater(store: store, valuePath: value, publisherPath: publisher)
    }
    
    init(
        wrappedValue: V,
        _ store: Keypr,
        _ name: String,
    ) {
        keypUpdater = NameKeypUpdater(store: store, name: name, default: wrappedValue)
    }
}

@Observable
private class KeypUpdater<V: Codable & Sendable> {
    var storedValue: V
    
    init(storedValue: V) {
        self.storedValue = storedValue
    }
    
    func updateValue(_ value: V) {
        storedValue = value
    }
}

@Observable
private class PathKeypUpdater<V: Codable & Sendable>: KeypUpdater<V> {
    private let store: Keypr
    private let valuePath: ReferenceWritableKeyPath<KeyprValues, V>
    private var cancellable: AnyCancellable?
    
    init(
        store: Keypr,
        valuePath: ReferenceWritableKeyPath<KeyprValues, V>,
        publisherPath: KeyPath<KeyprValues, AnyPublisher<V, Never>>
    ) {
        self.store = store
        self.valuePath = valuePath
        super.init(storedValue: store.values[keyPath: valuePath])
        
        self.cancellable = store.values[keyPath: publisherPath]
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.storedValue = newValue
            }
    }
    
    override func updateValue(_ value: V) { store.values[keyPath: valuePath] = value }
    
    deinit { cancellable?.cancel() }
}

@Observable
private class NameKeypUpdater<V: Codable & Sendable>: KeypUpdater<V> {
    private let store: Keypr
    private let name: String
    private var cancellable: AnyCancellable?
    
    init(
        store: Keypr,
        name: String,
        default defaultValue: V
    ) {
        self.store = store
        self.name = name
        super.init(storedValue: store.values[name, default: defaultValue])
        // self.storedValue = store.values[name, default: defaultValue]
        
        self.cancellable = store.values.publisher(for: name, default: defaultValue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.storedValue = newValue
            }
    }
    
    override func updateValue(_ value: V) {
        store.values[name, default: storedValue] = value
    }
    
    deinit { cancellable?.cancel() }
}
