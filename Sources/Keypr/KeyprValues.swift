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
    private let queue = DispatchQueue(label: "com.keypr.values")
    
    internal let updater = PassthroughSubject<Void, Never>()
    
    public init() {}
    
    public subscript<V: Codable & Sendable>(name: String, default defaultValue: V) -> V {
        get {
            queue.sync {
                if let cached = cache[name],
                   let casted = cached as? V {
                    return casted
                }
                guard let data = encodedStorage[name],
                      let decoded = try? JSONDecoder().decode(V.self, from: data)
                else {
                    let value = defaultValue
                    cache[name] = value
                    return value
                }
                cache[name] = decoded
                return decoded
            }
        }
        set {
            queue.sync {
                self.cache[name] = newValue
                self.encodedStorage[name] = try! JSONEncoder().encode(newValue)
            }
            
            self.updater.send(Void())
            self.subject(for: name).send(newValue)
        }
    }
    
    public subscript<K: KeyprKey>(key: K.Type) -> K.Value {
        get { self[K.name, default: K.defaultValue] }
        set { self[K.name, default: K.defaultValue] = newValue }
    }
    
    public func publisher<K: KeyprKey>(for key: K.Type) -> AnyPublisher<K.Value, Never> {
        return publisher(for: K.name, default: K.defaultValue)
    }
    
    public func publisher<V: Codable & Sendable>(for name: String, default defaultValue: V) -> AnyPublisher<V, Never> {
        let initialValue = self[name, default: defaultValue]
        return subject(for: name)
            .map { $0 as! V }
            .prepend(initialValue)
            .eraseToAnyPublisher()
    }
    
    private func subject(for name: String) -> PassthroughSubject<Any, Never> {
        queue.sync {
            if let subject = subjects[name] as? PassthroughSubject<Any, Never> {
                return subject
            }
            
            let subject = PassthroughSubject<Any, Never>()
            subjects[name] = subject
            return subject
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case encodedStorage
    }
}
