//
//  KeyprIsolatedAccessor.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

/// Provides isolated, thread-safe access to a value in a `Keypr` store.
/// Encapsulates getter, setter, and streaming logic for a specific value.
/// - Note: The value type must conform to `Codable` and `Sendable`
public struct KeyprIsolatedAccessor<Value: Codable & Sendable>: Sendable {
    
    /// The default value used if no value is stored.
    let defaultValue: Value
    
    /// The `Keypr` store this value is accessed from.
    private let store: Keypr
    
    /// An isolated closure used to get the value from the store.
    private let getter: @Sendable (isolated Keypr) -> Value
    
    /// An isolated closure used to set the value in the store.
    private let setter: @Sendable (isolated Keypr, Value) -> Void
    
    /// An isolated closure used to delete the value from the store.
    private let deleter: @Sendable (isolated Keypr) -> Void
    
    /// An isolated closure used to create a stream of value updates.
    private let stream: @Sendable (isolated Keypr) -> Keypr.Stream<Value>
    
    /// Initializes an accessor with custom getter, setter, and stream closures.
    /// - Parameters:
    ///   - defaultValue: The default value to use.
    ///   - store: The `Keypr` store to access.
    ///   - getter: Closure to get the value from the store.
    ///   - setter: Optional closure to set the value in the store.
    ///   - stream: Closure to create a stream of value updates.
    public init(
        defaultValue: Value,
        isolatedTo store: Keypr,
        getter: @Sendable @escaping (isolated Keypr) -> Value,
        setter: @Sendable @escaping (isolated Keypr, Value) -> Void,
        deleter: @Sendable @escaping (isolated Keypr) -> Void,
        stream: @Sendable @escaping (isolated Keypr) -> Keypr.Stream<Value>
    ) {
        self.defaultValue = defaultValue
        self.store = store
        self.getter = getter
        self.setter = setter
        self.deleter = deleter
        self.stream = stream
    }
    
    /// Returns an async stream of value updates from the store.
    func stream() async -> Keypr.Stream<Value> {
        await stream(store)
    }
    
    /// Gets the current value from the store asynchronously.
    func getValue() async -> Value {
        await getter(store)
    }
    
    /// Sets a new value in the store asynchronously.
    /// - Parameter value: The value to set.
    func setValue(_ value: Value) async {
        await setter(store, value)
    }
    
    /// Deletes the current value from the store asynchronously.
    func delete() async {
        await deleter(store)
    }
}
