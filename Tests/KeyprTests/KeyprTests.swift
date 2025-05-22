import Testing
import Foundation
import Keypr

struct ComplexType: Codable, Equatable {
    var name = UUID().uuidString
    var numbers = Array(1...3)
}

extension KeyprValues {
    @Keyed var myFeature: String = ""
    @Keyed var myComplexType: ComplexType? = nil
}

extension Keypr {
    static let main = Keypr(name: "main")!
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
