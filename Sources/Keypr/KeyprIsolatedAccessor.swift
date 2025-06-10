//
//  KeyprIsolatedAccessor.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

public struct KeyprIsolatedAccessor<Value: Codable & Sendable>: Sendable {
    
    let defaultValue: Value
    
    private let store: Keypr
    private let getter: @Sendable (isolated Keypr) -> Value
    private let setter: (@Sendable (isolated Keypr, Value) -> Void)?
    private let deleter: @Sendable (isolated Keypr) -> Void
    private let stream: @Sendable (isolated Keypr) -> Keypr.Stream<Value>
    
    public init(
        defaultValue: Value,
        isolatedTo store: Keypr,
        getter: @Sendable @escaping (isolated Keypr) -> Value,
        setter: (@Sendable (isolated Keypr, Value) -> Void)?,
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
    
    func stream() async -> Keypr.Stream<Value> {
        await stream(store)
    }
    
    func getValue() async -> Value {
        await getter(store)
    }
    
    func setValue(_ value: Value) async {
        await setter?(store, value)
    }
    
    func delete() async {
        await deleter(store)
    }
}
