import Testing
import Foundation
@testable import Keypr

struct ComplexType: Codable, Equatable {
    var name = UUID().uuidString
    var numbers = Array(1...3)
}

extension Keypr {
    static let main = Keypr(name: "main")!
}

fileprivate extension Keypr {
    @Keyed var testKey: Int = 42
    @Keyed var stringKey: String = "default"
    @Keyed var complexKey: ComplexData? = nil
    @Keyed var concurrent: Double = 0
}

fileprivate struct ComplexData: Codable, Sendable, Equatable {
    var name: String = UUID().uuidString
    var age: Int = Int.random(in: 0...90)
    var scores: [Double] = [
        Double.random(in: 0...1000),
        Double.random(in: 0...1000),
        Double.random(in: 0...1000),
        Double.random(in: 0...1000)
    ]
}

@Suite("KeyprValues Tests")
struct KeyprValuesTests {
    
    @Test("Test Get / Set Value by Name")
    func testGetSetValueByName() async throws {
        let values = Keypr(encodedStorage: [:])
        #expect(await values["foo", default: 123] == 123)
        try await values.setValue(456, for: "foo")
        #expect(await values["foo", default: 123] == 456)
    }
    
    @Test("Test Get / Set Value by Property")
    func testGetSetValueByProperty() async {
        let values = Keypr(encodedStorage: [:])
        let randomValue = Int.random(in: Int.min...Int.max)
        
        await values.mutate { k in
            k.testKey = randomValue
        }
        
        #expect(await values.testKey == randomValue)
    }
    
    @Test("Test Default is returned if value is not set")
    func testDefaultReturned() async {
        let values = Keypr(encodedStorage: [:])
        #expect(await values.stringKey == "default")
    }
    
    @Test("Test Thread Safety of values")
    func testThreadSafety() async {
        let values = Keypr(encodedStorage: [:])
        let iterations = 1000
        
        await withTaskGroup(of: Void.self) { group in
            for i in 1...iterations {
                group.addTask {
                    await values.mutate { k in
                        k.concurrent = Double(i)
                    }
                }
                group.addTask {
                    await _ = values.concurrent
                }
            }
        }
        
        // After all writes, the value should be between 1 and iterations
        let finalValue = await values.concurrent
        #expect((1...iterations).contains(Int(finalValue)), "Final value out of expected range: \(finalValue)")
    }
    
    @Test("Test Sequence Emits values on Change")
    func testSequenceEmitsValues() async {
        let values = Keypr(encodedStorage: [:])
        
        Task {
            // Delay to allow subscriber to setup
            try? await Task.sleep(for: .seconds(1))
            await values.mutate { k in
                k.testKey = 99
            }
            
            
            try? await Task.sleep(for: .seconds(1))
            await values.mutate { k in
                k.testKey = 404
            }
        }
        
        let stream = await values.$testKey
        var expectedValues = [42, 99, 404]
        for await value in stream {
            #expect(value == expectedValues.removeFirst())
            if expectedValues.isEmpty { break }
        }
    }
    
    @Test("Test Keypr encoding and decoding preserves values")
    func testKeyprEncodingDecoding() async throws {
        // Set up initial Keypr and values
        let original = Keypr(encodedStorage: [:])
        await original.mutate { k in
            k.testKey = 123
            k.stringKey = "hello"
            k.complexKey = ComplexData()
        }
        
        // Encode Keypr's Storage
        let encoded = try await original.encoded
        
        // Decode into a new Keypr
        let decodedStorage = try JSONDecoder().decode([String: Data].self, from: encoded)
        let decoded = Keypr(encodedStorage: decodedStorage)
        
        // Check values are preserved
        #expect(await decoded.testKey == original.testKey)
        #expect(await decoded.stringKey == original.stringKey)
        #expect(await decoded.complexKey == original.complexKey)
    }
}
