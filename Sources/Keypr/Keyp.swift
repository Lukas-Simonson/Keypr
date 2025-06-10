//
//  Keyp.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/21/25.
//

import SwiftUI

/// A property wrapper that provides a dynamic, observable binding to a value stored in a `Keypr` store.
/// Supports automatic updates and two-way binding for use in SwiftUI views.
/// - Note: The value type must conform to `Codable` and `Sendable`.
@MainActor @propertyWrapper
public struct Keyp<V: Codable & Sendable>: DynamicProperty {
    
    /// An internal updater that manages the stored value and updates.
    @State private var keypUpdater: KeypUpdater<V>
    
    
    /// The current value from the store.
    public var wrappedValue: V {
        get { keypUpdater.storedValue }
        nonmutating set { keypUpdater.updateValue(newValue) }
    }
    
    /// A binding to the value, for use in SwiftUI.
    public var projectedValue: Binding<V> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    /// Initializes the property wrapper with a custom accessor.
    /// - Parameters accessor: An accessor for isolated `Keypr` store access.
    init(_ accessor: KeyprIsolatedAccessor<V>) {
        keypUpdater = AccessorKeypUpdater(accessor: accessor)
    }
    
    /// Initializes the property wrapper with a store, key name, and default value.
    /// - Parameters:
    ///   - wrappedValue: The default value.
    ///   - store: The `Keypr` store.
    ///   - name: The key name.
    init(wrappedValue: V, _ store: Keypr, _ name: String) {
        keypUpdater = NamedKeypUpdater(store: store, name: name, defaultValue: wrappedValue)
    }
}

/// An observable base class for managing a stored value and updating it.
/// Used internally by the `Keyp` property wrapper.
@Observable @MainActor
private class KeypUpdater<V: Codable & Sendable> {
    
    /// The current stored value.
    var storedValue: V
    
    /// Initializes with an initial stored value.
    /// - Parameter storedValue: The initial value.
    init(storedValue: V) {
        self.storedValue = storedValue
    }
    
    /// Updates the stored value.
    /// - Parameter value: The new value.
    func updateValue(_ value: V) {
        storedValue = value
    }
}

/// An observable updater that syncs with a `KeyprIsolatedAccessor`.
/// Listens for value changes and updates accordingly.
@Observable @MainActor
private class AccessorKeypUpdater<V: Codable & Sendable>: KeypUpdater<V> {
    
    /// The accessor for isolated `Keypr` access.
    private let accessor: KeyprIsolatedAccessor<V>
    
    /// Initializes with an accessor and starts listening for value changes.
    /// - Parameter accessor: The accessor to observe.
    init(accessor: KeyprIsolatedAccessor<V>) {
        self.accessor = accessor
        super.init(storedValue: accessor.defaultValue)
        
        Task { [weak self] in
            let stream = await accessor.stream()
            for try await element in stream {
                guard let self else { break }
                self.storedValue = element
            }
        }
    }
    
    /// Updates the value in the underlying accessor asynchronously.
    /// - Parameter value: The new value.
    override func updateValue(_ value: V) {
        Task {
            await accessor.setValue(value)
        }
    }
}

/// An observable updater that syncs with a `Keypr` store and key name.
/// Listens for value changes and updates accordingly.
@Observable @MainActor
private class NamedKeypUpdater<V: Codable & Sendable>: KeypUpdater<V> {
    
    /// The `Keypr` store this value is stored in.
    private let store: Keypr
    
    /// The key name.
    private let name: String
    
    /// The default / initial value.
    private let defaultValue: V
    
    /// Initializes with a store, key name, and default value, and starts listening for value changes.
    /// - Parameters:
    ///   - store: The `Keypr` store.
    ///   - name: The key name.
    ///   - defaultValue: The default value.
    init(store: Keypr, name: String, defaultValue: V) {
        self.store = store
        self.name = name
        self.defaultValue = defaultValue
        super.init(storedValue: defaultValue)
        
        Task { [weak self] in
            let stream = await store.stream(for: name, default: defaultValue)
            for try await element in stream {
                guard let self else { break }
                self.storedValue = element
            }
        }
    }
    
    /// Updates the value in the underlying store asynchronously.
    /// - Parameter value: The new value.
    override func updateValue(_ value: V) {
        Task {
            await store.setValue(value, for: name)
        }
    }
}
