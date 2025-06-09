import Testing
import Foundation
@testable @preconcurrency import Keypr

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
    
    
    @Test("Test Publisher emits values on change")
    func testPublisherEmitsValues() async {
        let values = Keypr(encodedStorage: [:])
        var received: [Int] = []
        let expectation = AsyncExpectation()
        let cancellable = await values.$testKey
            .sink { value in
                received.append(value)
                if received.count == 2 {
                    Task { await expectation.fulfill() }
                }
            }
        
        try! await values.setValue(99, for: "testKey")
        
        await expectation.wait()
        
        #expect(received[0] == 42) // initial value
        #expect(received[1] == 99) // updated value
        
        _ = cancellable // keep alive
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

actor AsyncExpectation {
    private var fulfilled = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    
    func fulfill() {
        fulfilled = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
    
    func wait() async {
        if fulfilled { return }
        await withCheckedContinuation { cont in
            continuations.append(cont)
        }
    }
}

//@Test
//func example() async throws {
//    
//    let store = Keypr.main
//    
//    store.myFeature = "Hello, World!"
//    store.myComplexType = ComplexType()
//    
//    let c = store.values.publisher(for: "dynamic_key", default: "no_value")
//        .sink { print($0) }
//    
//    store.values["dynamic_key", default: "no_value"] = "cool value"
//    
//    let encoded = try JSONEncoder().encode(store.values)
//    let decoded = try JSONDecoder().decode(KeyprValues.self, from: encoded)
//
//    #expect(decoded.myFeature == store.myFeature)
//    #expect(decoded.myComplexType == store.myComplexType)
//    #expect(decoded["dynamic_key", default: "some_value"] == store.values["dynamic_key", default: "no_value"])
//}
