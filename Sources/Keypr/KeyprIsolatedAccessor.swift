//
//  KeyprIsolatedAccessor.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

@preconcurrency import Combine

public struct KeyprIsolatedAccessor<Value: Sendable>: Sendable {
    
    let defaultValue: Value
    
    private let isolatedTo: Keypr
    private let getter: @Sendable (isolated Keypr) -> Value
    private let setter: (@Sendable (isolated Keypr, Value) -> Void)?
    private let publisher: (@Sendable (isolated Keypr) -> AnyPublisher<Value, Never>)
    
    public init(
        defaultValue: Value,
        isolatedTo: Keypr,
        getter: @Sendable @escaping (isolated Keypr) -> Value,
        setter: (@Sendable (isolated Keypr, Value) -> Void)?,
        publisher: @Sendable @escaping (isolated Keypr) -> AnyPublisher<Value, Never>
    ) {
        self.defaultValue = defaultValue
        self.isolatedTo = isolatedTo
        self.getter = getter
        self.setter = setter
        self.publisher = publisher
    }
    
    func publisher() async -> AnyPublisher<Value, Never> {
        await publisher(isolatedTo)
    }
    
    func getValue() async -> Value {
        await getter(isolatedTo)
    }
    
    func setValue(_ value: Value) async {
        await setter?(isolatedTo, value)
    }
}
