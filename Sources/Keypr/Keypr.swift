// The Swift Programming Language
// https://docs.swift.org/swift-book

//import Foundation
@_exported @preconcurrency import Combine

import Foundation

public protocol KeyprKey {
    associatedtype Value: Codable & Sendable
    static var name: String { get }
    static var defaultValue: Value { get }
}

public actor Keypr {
    public let pathURL: URL?
    
    private var encodedStorage: [String: Data]
    private var cache: [String: Any] = [:]
    private var subjects: [String: Any] = [:]
    
    private var saveTask: Task<Void, Error>? = nil
    
    public init(path: URL) throws {
        self.pathURL = path
        let pathStr = path.path(percentEncoded: false)
        
        self.encodedStorage = if (FileManager.default.fileExists(atPath: pathStr)) {
            try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: path))
        } else { [:] }
    }
    
    public init?(name: String) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let regexPattern = try? Regex("[<>:\"/\\\\|?*\\s\u{0000}-\u{001F}]")
        else { return nil }
        
        let fileName = name.replacing(regexPattern, with: "")
        try? self.init(path: directory.appending(path: ".\(fileName).keyp"))
    }
    
    internal init(encodedStorage: [String: Data]) {
        self.pathURL = nil
        self.encodedStorage = encodedStorage
    }
}

// MARK: Subscripts
extension Keypr {
    
    public subscript<K: KeyprKey>(key: K.Type) -> K.Value {
        get { self[K.name, default: K.defaultValue] }
        set { self[K.name, default: K.defaultValue] = newValue }
    }
    
    public subscript<V: Codable & Sendable>(name: String, default defaultValue: V) -> V {
        get { getValue(for: name, default: defaultValue) }
        set { try? setValue(newValue, for: name) }
    }
    
    public func getValue<V: Codable & Sendable>(for name: String, default dv: V) -> V {
        if let cached = cache[name],
           let casted = cached as? V
        { return casted }
        
        guard let data = encodedStorage[name],
              let decoded = try? JSONDecoder().decode(V.self, from: data)
        else {
            cache[name] = dv
            return dv
        }
        
        cache[name] = decoded
        return decoded
    }
    
    public func setValue<V: Codable & Sendable>(_ value: V, for name: String) throws {
        self.cache[name] = value
        self.subject(for: name).send(value)
        self.encodedStorage[name] = try JSONEncoder().encode(value)
        self.save()
    }
    
    public func mutate<V: Codable & Sendable>(_ modifying: @Sendable (isolated Keypr) async throws -> V) async rethrows -> V {
        return try await modifying(self)
    }
    
    public func mutate(_ modifying: @Sendable (isolated Keypr) async throws -> Void) async rethrows {
        try await modifying(self)
    }
    
    nonisolated public func mutate(_ modifying: @escaping @Sendable (isolated Keypr) async -> Void) {
        Task { await modifying(self) }
    }
}

// MARK: Combine
extension Keypr {
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
        if let subject = subjects[name] as? PassthroughSubject<Any, Never> {
            return subject
        }
        
        let subject = PassthroughSubject<Any, Never>()
        subjects[name] = subject
        return subject
    }
}

// MARK: Persistence
extension Keypr {
    public func save() {
        saveTask = Task { try? await save() }
    }
    
    public func save() async throws {
        guard let pathURL else { return }
        
        saveTask?.cancel()
        
        try await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        
        let pathStr = pathURL.path(percentEncoded: false)
        let encodedData = try encoded
        
        if (FileManager.default.fileExists(atPath: pathStr)) {
            try encodedData.write(to: pathURL)
        } else {
            FileManager.default.createFile(
                atPath: pathStr,
                contents: encodedData,
                attributes: [
                    // No file protections
                    FileAttributeKey.protectionKey: FileProtectionType.none
                ]
            )
        }
    }
    
    static func removeKeypr(named name: String) throws {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let regexPattern = try? Regex("[<>:\"/\\\\|?*\\s\u{0000}-\u{001F}]")
        else { return }
        
        let fileName = name.replacing(regexPattern, with: "")
        try removeKeypr(atPath: directory.appending(path: ".\(fileName).keyp"))
    }
    
    static func removeKeypr(atPath path: URL) throws {
        if FileManager.default.isDeletableFile(atPath: path.absoluteString) {
            try FileManager.default.removeItem(at: path)
        }
    }
    
    internal var encoded: Data {
        get throws { try JSONEncoder().encode(encodedStorage) }
    }
    
    internal static func decoded(_ data: Data) throws -> Keypr {
        let encoded = try JSONDecoder().decode([String: Data].self, from: data)
        return Keypr(encodedStorage: encoded)
    }
}
