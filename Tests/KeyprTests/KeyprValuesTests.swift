//
//  KeyprValuesTests.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/21/25.
//

import Testing
import Combine
import Foundation
@testable import Keypr

fileprivate extension KeyprValues {
    @Keyed var testKey: Int = 42
    @Keyed var stringKey: String = "default"
    @Keyed var complexKey: ComplexData? = nil
    @Keyed var concurrent: Double = 0
}

fileprivate struct ComplexData: Codable, Sendable {
    var name: String = UUID().uuidString
    var age: Int = Int.random(in: 0...90)
    var scores: [Double] = [
        Double.random(in: 0...1000),
        Double.random(in: 0...1000),
        Double.random(in: 0...1000),
        Double.random(in: 0...1000)
    ]
}

@Suite("KeyprValues Tests") @MainActor
struct KeyprValuesTests {
    
    @Test("Test Get / Set Value by Name")
    func testGetSetValueByName() {
        let values = KeyprValues()
        #expect(values["foo", default: 123] == 123)
        values["foo", default: 123] = 456
        #expect(values["foo", default: 123] == 456)
    }
    
    @Test("Test Get / Set Value by Property")
    func testGetSetValueByProperty() {
        let values = KeyprValues()
        
        let randomValue = Int.random(in: Int.min...Int.max)
        
        values.testKey = randomValue
        #expect(values.testKey == randomValue)
    }
    
    @Test("Test Default is returned if value is not set")
    func testDefaultReturned() {
        let values = KeyprValues()
        #expect(values.stringKey == "default")
    }
    
    @Test("Test Codable Functionality")
    func testCodableFunctionality() throws {
        let values = KeyprValues()
        values.testKey = 77
        values.stringKey = "Hello, World!"
        
        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode(KeyprValues.self, from: data)
        
        #expect(values.testKey == decoded.testKey)
        #expect(values.stringKey == decoded.stringKey)
    }
    
    @Test("Test Thread Safety of values")
    func testThreadSafety() async {
        let values = KeyprValues()
        let iterations = 1000
        
        await withTaskGroup(of: Void.self) { group in
            for i in 1...iterations {
                group.addTask { @MainActor in
                    values.concurrent = Double(i)
                }
                group.addTask { @MainActor in
                    _ = values.concurrent
                }
            }
        }
        
        // After all writes, the value should be between 1 and iterations
        let finalValue = values.concurrent
        #expect((1...iterations).contains(Int(finalValue)), "Final value out of expected range: \(finalValue)")
    }
}
