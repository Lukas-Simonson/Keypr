//
//  AnyKeyable.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

import Foundation

public final class AnyKeyable: Encodable, Sendable {
    private let _value: @Sendable () -> Any
    private let _encode: @Sendable (Encoder) throws -> Void
    
    internal init<T: Codable & Sendable>(_ base: T) {
        _value = { base }
        _encode = { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(base)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
    
    func value<T: Encodable & Sendable>(as type: T.Type) -> T? {
        _value() as? T
    }
}
