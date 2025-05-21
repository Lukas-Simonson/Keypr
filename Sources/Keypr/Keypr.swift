// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@_exported import Combine

@dynamicMemberLookup
public final class Keypr: @unchecked Sendable {
    public let pathURL: URL
    public let values: KeyprValues
    
    private(set) var cancellable: AnyCancellable?
    
    public init(path: URL) throws {
        self.pathURL = path
        let pathStr = pathURL.path(percentEncoded: false)
        
        self.values = if (FileManager.default.fileExists(atPath: pathStr)) {
            try JSONDecoder().decode(KeyprValues.self, from: Data(contentsOf: pathURL))
        } else {
            KeyprValues()
        }
        
        self.cancellable = self.values.updater
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global())
            .sink { _ in try? self.save() }
    }
    
    public func save() throws {
        let pathStr = pathURL.path(percentEncoded: false)
        let encodedData = try JSONEncoder().encode(values)
        
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
    
    public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<KeyprValues, T>) -> T {
        get { values[keyPath: keyPath] }
        set { values[keyPath: keyPath] = newValue }
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<KeyprValues, T>) -> T {
        get { values[keyPath: keyPath] }
    }
}

public extension Keypr {
    convenience init?(name: String) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let regexPattern = try? Regex("[<>:\"/\\\\|?*\\s\u{0000}-\u{001F}]")
        else { return nil }
        
        let fileName = name.replacing(regexPattern, with: "")
        try? self.init(path: directory.appending(path: ".\(fileName).keyp"))
    }
}


