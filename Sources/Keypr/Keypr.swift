// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

/// A protocol representing a key for use with a `Keypr` store.
public protocol KeyprKey {
    
    /// The value this Key is associated with.
    associatedtype Value: Codable & Sendable
    
    /// The unique name of the key.
    static var name: String { get }
    
    /// The default value if no value is found for this key.
    static var defaultValue: Value { get }
}

/// An actor based key-value store supporting persistence, observation, and mutation.
/// Stores `Codable & Sendable` conforming types into a file stored on disk.
public actor Keypr {
    /// The file URL where the store is persisted.
    public let pathURL: URL?
    
    /// The on disk data representation values.
    private var encodedStorage: [String: Data]
    
    /// Cached decoded values, helps prevent repeated decoding.
    private var cache: [String: AnyKeyable] = [:]
    
    /// An `AsyncSequence` that streams updates to the cache.
    private let sequence = AsyncStateSequence<[String: AnyKeyable]>(initial: [:])
    
    /// A `Task` used to debounce save requests.
    private var saveTask: Task<Void, Error>? = nil
    
    /// Creates an in-memory `Keypr` store.
    public init() throws {
        self.pathURL = nil
        self.encodedStorage = [:]
    }
    
    /// Initializes a `Keypr` instance with a file  path for persistence.
    /// - Parameter path: The file URL to persist the store.
    /// - Throws: A DecodingError if the file cannot be decoded.
    public init(path: URL) throws {
        self.pathURL = path
        let pathStr = path.path(percentEncoded: false)
        
        self.encodedStorage = if (FileManager.default.fileExists(atPath: pathStr)) {
            try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: path))
        } else { [:] }
    }
    
    /// Initializes a `Keypr` instance with a name, storing the file in the users document directory.
    /// - Parameter name: The name for the persistent store.
    /// Returns `nil` if the name is invalid or the directory cannot be used.
    public init?(name: String) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let regexPattern = try? Regex("[<>:\"/\\\\|?*\\s\u{0000}-\u{001F}]")
        else { return nil }
        
        let fileName = name.replacing(regexPattern, with: "")
        try? self.init(path: directory.appending(path: ".\(fileName).keyp"))
    }
    
    /// Internal initializer for use when testing.
    internal init(encodedStorage: [String: Data]) {
        self.pathURL = nil
        self.encodedStorage = encodedStorage
    }
}

// MARK: Subscripts
extension Keypr {
    
    /// Accesses the value associated with a `KeyprKey` type.
    /// - Parameter key: The key type.
    public subscript<K: KeyprKey>(key: K.Type) -> K.Value {
        get { self[K.name, default: K.defaultValue] }
        set { self[K.name, default: K.defaultValue] = newValue }
    }
    
    /// Accesses the value for a given name, providing a default value if not present.
    /// - Parameters:
    ///   - name: The key name.
    ///   - defaultValue: The default value to use if a value is not present.
    public subscript<V: Codable & Sendable>(name: String, default defaultValue: V) -> V {
        get { getValue(for: name, default: defaultValue) }
        set { setValue(newValue, for: name) }
    }
    
    /// Retrieves the value for a given name, or returns the default value.
    /// - Parameters:
    ///   - name: The key name.
    ///   - dv: The default value.
    /// - Returns: The stored or default value.
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
        
        // Moves value from encodedStorage into cache
        encodedStorage.removeValue(forKey: name)
        cache[name] = AnyKeyable(decoded)
        return decoded
    }
    
    /// Sets the value for a given name.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - name: The key name.
    public func setValue<V: Codable & Sendable>(_ value: V, for name: String) {
        self.cache[name] = AnyKeyable(value)
        self.sequence.emit(cache)
        self.save()
    }
    
    /// Mutates the store using an async closure, returning a value.
    /// - Parameter modifying: The closure used to mutate the store.
    /// - Returns: The result of the closure.
    public func mutate<V: Codable & Sendable>(_ modifying: @Sendable (isolated Keypr) async throws -> V) async rethrows -> V {
        return try await modifying(self)
    }
    
    /// Mutates the store using an async closure.
    /// - Parameter modifying: The closure used to mutate the store.
    public func mutate(_ modifying: @Sendable (isolated Keypr) async throws -> Void) async rethrows {
        try await modifying(self)
    }
    
    /// Mutates the store using a non-isolated async closure.
    ///
    /// This function allows concurrent modification of a `Keypr` store; however, the modifications
    /// are run on a background task and may not be applied directly after calling this function.
    /// You can use the `async` version of this function to handle changes immediately after applying them.
    ///
    /// - Parameter modifying: The closure to mutate the store.
    nonisolated public func mutate(_ modifying: @escaping @Sendable (isolated Keypr) async -> Void) {
        Task { await modifying(self) }
    }
    
    /// Deletes the key-value pair from the store using the provided `KeyprKey` type.
    ///
    /// This will remove the value from both the in-memory and persisted data.
    /// Attempting to read the value stored with the key after deleting will result
    /// in the default value.
    ///
    /// - Parameter key: The `KeyprKey` Type you want to remove the value of.
    public func delete<K: KeyprKey>(_ key: K.Type) {
        self.delete(key.name)
    }
    
    /// Deletes the key-value pair from the store using the provided name.
    ///
    /// This will remove the value from both the in-memory and persisted data.
    /// Attempting to read the value stored with the name after deleting will result
    /// in the default value.
    ///
    /// - Parameter name: The name of the key-value pair you want to remove.
    public func delete(_ name: String) {
        self.cache.removeValue(forKey: name)
        self.encodedStorage.removeValue(forKey: name)
        self.save()
    }
}

// MARK: Observation
extension Keypr {
    
    /// A typealias for a mapped AsyncSequence providing a single value from the cache.
    public typealias Stream<V: Codable & Sendable> = AsyncCompactMapSequence<AsyncStateSequence<[String: AnyKeyable]>, V>
    
    /// Returns a stream of values for the given `KeyprKey` type.
    /// - Parameter key: The key type.
    public func stream<K: KeyprKey>(for key: K.Type) -> Stream<K.Value> {
        stream(for: key.name, default: key.defaultValue)
    }
    
    /// Returns a stream of values for the given name and default value.
    /// - Parameters:
    ///   - name: The key name.
    ///   - dv: The default value.
    public func stream<V: Codable & Sendable>(for name: String, default dv: V) -> Stream<V> {
        let initial = getValue(for: name, default: dv)
        return sequence.compactMap { $0[name]?.value(as: V.self) ?? initial }
    }
}

// MARK: Persistence
extension Keypr {
    /// Schedules a save operation to persist the store to disk.
    public nonisolated func save() {
        Task { try? await save() }
    }
    
    /// Debounces any current autosave() calls and starts a new one.
    private func autosave() {
        guard let pathURL else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            
            try await self?.persist()
        }
    }
    
    /// Immediately saves the store to disk.
    /// - Throws: an error if writing or encoding fails.
    public func save() async throws {
        saveTask?.cancel()
        try await persist()
    }
    
    /// Persists the store to disk.
    /// - Throws: An error if writing fails.
    private func persist() async throws {
        guard let pathURL else { return }
        
        let pathStr = pathURL.path(percentEncoded: false)
        let encodedData = try encode()
        
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
    
    /// Removes a persisted store by name.
    /// - Parameter name: The name of the store to remove.
    /// - Throws: An error if removal fails.
    public static func removeKeypr(named name: String) throws {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let regexPattern = try? Regex("[<>:\"/\\\\|?*\\s\u{0000}-\u{001F}]")
        else { return }
        
        let fileName = name.replacing(regexPattern, with: "")
        try removeKeypr(atPath: directory.appending(path: ".\(fileName).keyp"))
    }
    
    /// Removes a persisted store at a given path.
    /// - Parameter path: The file URL to remove.
    /// - Throws: An error if removal fails.
    public static func removeKeypr(atPath path: URL) throws {
        try FileManager.default.removeItem(at: path)
    }
    
    /// Creates an encoded `[String: Data]` will all values to persist to disk.
    /// - Throws: An `EncodingError` if encoding cannot be completed.
    internal func encode() throws -> Data {
        var valuesToEncode = encodedStorage
        for (key, value) in cache {
            valuesToEncode[key] = try JSONEncoder().encode(value)
        }
        
        return try JSONEncoder().encode(valuesToEncode)
    }
}
