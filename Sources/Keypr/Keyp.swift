//
//  Keyp.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/21/25.
//

import SwiftUI
@preconcurrency import Combine

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
    
    init(_ accessor: KeyprIsolatedAccessor<V>) {
        keypUpdater = AccessorKeypUpdater(accessor: accessor)
    }
    
    init(wrappedValue: V, _ store: Keypr, _ name: String) {
        keypUpdater = NamedKeypUpdater(store: store, name: name, defaultValue: wrappedValue)
    }
}

@Observable @MainActor
private class KeypUpdater<V: Codable & Sendable> {
    var storedValue: V
    
    init(storedValue: V) {
        self.storedValue = storedValue
    }
    
    func updateValue(_ value: V) {
        storedValue = value
    }
}

@Observable @MainActor
private class AccessorKeypUpdater<V: Codable & Sendable>: KeypUpdater<V> {
    
    private let accessor: KeyprIsolatedAccessor<V>
    
    private var cancellable: AnyCancellable?
    
    init(accessor: KeyprIsolatedAccessor<V>) {
        self.accessor = accessor
        super.init(storedValue: accessor.defaultValue)
        
        Task { [weak self] in
            self?.cancellable = await accessor.publisher()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.storedValue = newValue
                    print("Updating Stored Value to \(newValue)")
                }
        }
    }
    
    override func updateValue(_ value: V) {
        Task {
            await accessor.setValue(value)
        }
    }
}

@Observable @MainActor
private class NamedKeypUpdater<V: Codable & Sendable>: KeypUpdater<V> {
    
    private let store: Keypr
    private let name: String
    private let defaultValue: V
    
    private var cancellable: AnyCancellable?
    
    init(store: Keypr, name: String, defaultValue: V) {
        self.store = store
        self.name = name
        self.defaultValue = defaultValue
        super.init(storedValue: defaultValue)
        
        Task { [weak self] in
            self?.cancellable = await store.publisher(for: name, default: defaultValue)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.storedValue = newValue
                    print("Updating Stored Value to \(newValue)")
                }
        }
    }
    
    override func updateValue(_ value: V) {
        Task {
            try? await store.setValue(value, for: name)
        }
    }
}
