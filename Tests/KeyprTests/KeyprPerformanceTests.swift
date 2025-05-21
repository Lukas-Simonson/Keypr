//
//  KeyprPerformanceTests.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/21/25.
//

import XCTest
@testable import Keypr

extension KeyprValues {
    @Keyed var heavy: Array<Int> = Array(0..<1000)
}

final class SettingsStorePerformanceTests: XCTestCase {
    
    func testReadPerformance() {
        let store = Keypr(name: "main")!
        store.heavy = Array(0..<1000)
        
        measure {
            for _ in 0..<1000 {
                _ = store.heavy
            }
        }
    }
    
    func testWritePerformance() {
        let store = Keypr(name: "main")!
        
        measure {
            for i in 0..<1000 {
                store.heavy = Array(0..<i)
            }
        }
    }
    
    func testEncodePerformance() {
        let store = Keypr(name: "main")!
        store.heavy = Array(0..<1000)
        
        measure {
            _ = try? JSONEncoder().encode(store.values)
        }
    }
    
    func testDecodePerformance() {
        let store = Keypr(name: "main")!
        store.heavy = Array(0..<1000)
        let data = try! JSONEncoder().encode(store.values)
        
        measure {
            _ = try? JSONDecoder().decode(KeyprValues.self, from: data)
        }
    }
}

final class UserDefaultsPerformanceTests: XCTestCase {
    
    let key = "heavyKey"
    let defaults = UserDefaults.standard
    
    override func setUp() {
        super.setUp()
        // Clean slate
        defaults.removeObject(forKey: key)
    }
    
    override func tearDown() {
        defaults.removeObject(forKey: key)
        super.tearDown()
    }
    
    func testReadPerformance() {
        let value = Array(0..<1000)
        defaults.set(value, forKey: key)
        
        measure {
            for _ in 0..<1000 {
                _ = defaults.array(forKey: key) as? [Int]
            }
        }
    }
    
    func testWritePerformance() {
        measure {
            for i in 0..<1000 {
                defaults.set(Array(0..<i), forKey: key)
            }
        }
    }
    
    func testEncodePerformance() {
        let value = Array(0..<1000)
        defaults.set(value, forKey: key)
        
        measure {
            // Simulate encoding cost by pulling data from disk-backed store
            _ = defaults.dictionaryRepresentation()
        }
    }
    
    func testDecodePerformance() {
        let value = Array(0..<1000)
        defaults.set(value, forKey: key)
        
        measure {
            _ = defaults.array(forKey: key) as? [Int]
        }
    }
}
