//
//  KeyprValues.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/20/25.
//

import Foundation
import Combine

public protocol KeyprKey {
    associatedtype Value: Codable & Sendable
    static var name: String { get }
    static var defaultValue: Value { get }
}

public final class KeyprValues: Codable, @unchecked Sendable {
    private var encodedStorage: [String: Data] = [:]
    private var cache: [String: Any] = [:]
    private var subjects: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.keypr.values", attributes: .concurrent)
    
    internal let updater = PassthroughSubject<Void, Never>()
    
    public init() {}
    
    public subscript<K: KeyprKey>(key: K.Type) -> K.Value {
        get {
            queue.sync {
                if let cached = cache[K.name],
                   let casted = cached as? K.Value {
                    return casted
                }
                guard let data = encodedStorage[K.name],
                      let decoded = try? JSONDecoder().decode(K.Value.self, from: data)
                else {
                    let value = K.defaultValue
                    cache[K.name] = value
                    return value
                }
                cache[K.name] = decoded
                return decoded
            }
        }
        set {
            queue.sync {
                self.cache[K.name] = newValue
                self.encodedStorage[K.name] = try! JSONEncoder().encode(newValue)
                self.queue.async {
                    self.updater.send(Void())
                    self.subject(for: K.self).send(newValue)
                }
            }
        }
    }
    
    public func publisher<K: KeyprKey>(for key: K.Type) -> AnyPublisher<K.Value, Never> {
        let initialValue = self[key]
        return subject(for: K.self)
            .map { $0 as! K.Value }
            .prepend(initialValue)
            .eraseToAnyPublisher()
    }
    
    private func subject<K: KeyprKey>(for key: K.Type) -> PassthroughSubject<Any, Never> {
        queue.sync {
            if let subject = subjects[K.name] as? PassthroughSubject<Any, Never> {
                return subject
            }
            let subject = PassthroughSubject<Any, Never>()
            subjects[K.name] = subject
            return subject
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case encodedStorage
    }
}
