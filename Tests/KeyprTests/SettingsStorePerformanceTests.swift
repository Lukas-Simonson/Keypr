//
//  SettingsStorePerformanceTests.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

import XCTest
@testable import Keypr

extension Keypr {
    @Keyed var numbers: [Int] = []
}

let testSize = 1000
var metrics: [XCTMetric] {
    return [XCTMemoryMetric(), XCTCPUMetric(), XCTClockMetric()]
}

final class SettingsStorePerformanceTests: XCTestCase {
    
    override func setUp() async throws {
        try Keypr.removeKeypr(named: "main")
    }
    
    override func tearDown() async throws {
        try Keypr.removeKeypr(named: "main")
    }
    
    func testReadPerformance() async {
        let store = Keypr(name: "main")!
        
        await store.mutate { k in
            k.numbers = Array(0..<testSize)
        }
        
        measure(metrics: metrics) {
            let exp = expectation(description: "Read Times")
            Task {
                for _ in 0..<testSize {
                    _ = await store.numbers
                }
                exp.fulfill()
            }
            wait(for: [exp])
        }
    }
    
    func testWritePerformance() {
        let store = Keypr(name: "main")!
        
        measure(metrics: metrics) {
            let exp = expectation(description: "Write Times")
            Task {
                for i in 0..<testSize {
                    await store.mutate { k in
                        k.numbers = Array(0..<i)
                    }
                }
                try await store.save()
                exp.fulfill()
            }
            wait(for: [exp])
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
        let value = Array(0..<testSize)
        defaults.set(value, forKey: key)
        
        measure(metrics: metrics) {
            for _ in 0..<testSize {
                _ = defaults.array(forKey: key) as? [Int]
            }
        }
    }
    
    func testWritePerformance() {
        measure(metrics: metrics) {
            for i in 0..<testSize {
                defaults.set(Array(0..<i), forKey: key)
            }
        }
    }
}
