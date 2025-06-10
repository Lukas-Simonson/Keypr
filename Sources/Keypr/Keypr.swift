// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public protocol KeyprKey {
    associatedtype Value: Codable & Sendable
    static var name: String { get }
    static var defaultValue: Value { get }
}

public actor Keypr {
    public let pathURL: URL?
    
    private var encodedStorage: [String: Data]
    private var cache: [String: AnyKeyable] = [:]
    private let sequence = AsyncStateSequence<[String: AnyKeyable]>(initial: [:])
    
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
           let casted = cached.value(as: V.self)
        { return casted }
        
        guard let data = encodedStorage[name],
              let decoded = try? JSONDecoder().decode(V.self, from: data)
        else {
            cache[name] = AnyKeyable(dv)
            return dv
        }
        
        cache[name] = AnyKeyable(decoded)
        return decoded
    }
    
    public func setValue<V: Codable & Sendable>(_ value: V, for name: String) throws {
        self.cache[name] = AnyKeyable(value)
        self.sequence.emit(cache)
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
    
    public func delete<K: KeyprKey>(_ key: K.Type) {
        self.delete(key.name)
    }
    
    public func delete(_ name: String) {
        self.cache.removeValue(forKey: name)
        self.encodedStorage.removeValue(forKey: name)
        self.save()
    }
}

// MARK: Observation
extension Keypr {
    public typealias Stream<V: Codable & Sendable> = AsyncCompactMapSequence<AsyncStateSequence<[String: AnyKeyable]>, V>
    
    public func stream<K: KeyprKey>(for key: K.Type) -> Stream<K.Value> {
        stream(for: key.name, default: key.defaultValue)
    }
    
    public func stream<V: Codable & Sendable>(for name: String, default dv: V) -> Stream<V> {
        let initial = getValue(for: name, default: dv)
        return sequence.compactMap { $0[name]?.value(as: V.self) ?? initial }
    }
}

// MARK: Persistence
extension Keypr {
    public nonisolated func save() {
        Task { try? await save() }
    }
    
    private func autosave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            
            try await self?.persist()
        }
    }
    
    public func save() async throws {
        saveTask?.cancel()
        try await persist()
    }
    
    private func persist() async throws {
        guard let pathURL else { return }
        
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
        get throws {
            // Update encoded storage with cached values
            for (key, value) in cache {
                encodedStorage[key] = try JSONEncoder().encode(value)
            }
            
            return try JSONEncoder().encode(encodedStorage)
        }
    }
    
    internal static func decoded(_ data: Data) throws -> Keypr {
        let encoded = try JSONDecoder().decode([String: Data].self, from: data)
        return Keypr(encodedStorage: encoded)
    }
}
