//
//  Sample.swift
//  Keypr
//
//  Created by Lukas Simonson on 6/9/25.
//

import SwiftUI

// MARK: - Creating Stores
fileprivate extension Keypr {
    static let main = Keypr(name: "main")!
    static let secondary = try! Keypr(path: URL(filePath: "/Path/To/File/Location")!)
}

// MARK: - Creating Keys
fileprivate extension Keypr {
    @Keyed var exampleBoolean: Bool = false
    @Keyed var exampleInt: Int = 42
    @Keyed var myString: String = ""
    @Keyed var emptyValue: Double? = nil
}

// MARK: - Reading Values
fileprivate func readValue() async {
    let myBool = await Keypr.main.exampleBoolean
    let myInt = await Keypr.secondary.exampleInt
}

// When reading dynamic values, you must always provide a default value that can be used.
fileprivate func readDynValue() async {
    let myDynamicBool = await Keypr.main.getValue(for: "dynBool", default: false)
    let myDynamicInt = await Keypr.secondary.getValue(for: "favNumber", default: 42)
}

// MARK: - Writing Values
fileprivate func writeValue() {
    Keypr.main.mutate { k in
        k.exampleBoolean = true
        k.emptyValue = 64
    }
}

fileprivate func writeValueAsync() async {
    await Keypr.secondary.mutate { k in
        k.exampleInt = 123
    }
}


fileprivate func deleteValue() async {
    await Keypr.main._exampleInt.delete()
}

fileprivate func writeValue() async throws {
    try await Keypr.main.mutate { k in
        try k.setValue(123, for: "favNumber")
    }
    // or
    try await Keypr.main.setValue(456, for: "favNumber")
}

fileprivate func deleteDynValue() async {
    await Keypr.main.delete("favNumber")
}


// MARK: - Observing Values
fileprivate func observeValue() async {
    let stream = await Keypr.main.$exampleInt
    for await value in stream {
        print("Example Int Is Now: \(value)")
    }
}

fileprivate func observeDynValue() async {
    let stream = await Keypr.main.stream(for: "dynBool", default: false)
    for await value in stream {
        print("Dynamic Bool Is Now: \(value)")
    }
}

// MARK: - SwiftUI Integration

fileprivate struct ExampleView: View {
    
    @Keyp(Keypr.main._exampleBoolean) var isToggled
    @Keyp(Keypr.secondary._myString) var myString
    
    @Keyp(Keypr.main, "username") var username = "Default Value"
    
    var body: some View {
        VStack {
            Toggle("Am I Toggled?", isOn: $isToggled)
            TextField("My Favorite Word", text: $myString)
        }
    }
}

#Preview {
    ExampleView()
}

// MARK: - Persisting Data

func fireAndForgetSave() {
    Keypr.main.save()
}

func handleSave() async {
    do {
        try await Keypr.secondary.save()
        print("Save Completed...")
    } catch {
        // Handle Error
    }
}

func deleteStores() throws {
    try Keypr.removeKeypr(named: "main")
    try Keypr.removeKeypr(atPath: URL(filePath: "/Path/To/File/Location"))
}
