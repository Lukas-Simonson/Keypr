//
//  AnyKeyable.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

import Foundation

/// A type-erased wrapper for any value conforming to `Encodable` and `Sendable`.
/// Enables encoding and safe type casting of the underlying value.
/// Used to store heterogeneous values in a type-safe manner.
public final class AnyKeyable: Encodable, Sendable {
    
    /// Closure that returns the underlying value.
    private let _value: @Sendable () -> Any
    
    /// Closure that encodes the underlying value.
    private let _encode: @Sendable (Encoder) throws -> Void
    
    /// Initializes the wrapper with its wrapped value.
    /// - Parameter base: The value to wrap, must conform to `Encodable` and `Sendable`
    internal init<T: Codable & Sendable>(_ base: T) {
        _value = { base }
        _encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(base)
        }
    }
    
    /// Encodes the underlying value using the provided encoder.
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
    
    /// Attempts to cast the underlying value to a specific type.
    /// - Parameter type: The type to cast to.
    /// - Returns: The value cast to the specified type, or `nil` if the cast fails.
    func value<T: Encodable & Sendable>(as type: T.Type) -> T? {
        _value() as? T
    }
}
