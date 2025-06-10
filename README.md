<div align="center">
    <img alt="Keypr: Compile-Time Safe Key Value Storage" src="https://github.com/Lukas-Simonson/Keypr/blob/main/logo.png">
</div>

<h3 align="center">Keypr</h3>
<p align="center">Compile-Time Safe Key Value Storage</p>

<p align="center">
    <a href="https://developer.apple.com/swift/"><img alt="Swift 5.10" src="https://img.shields.io/badge/swift-5.10-orange.svg?style=flat"></a>
    <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-black.svg"></a>
</p>

## Overview

Keypr is a Swift package that provides a compile-time safe key-value storage system. A modern, safer, and faster alternative to `UserDefaults`. It offers a type-safe API for storing values with robust property observability and seamless SwiftUI integration.

Features:
- ✅ Compile-time safe key-value storage, eliminate stringly-typed keys and catch errors at build time
- 👀 Property observability, react to changes with minimal effort
- 🔄 Dynamic (runtime) storage support,  flexibility when static keys aren't feasible
- 💾 Automatic saving, persist values automatically, including while the app is in the background or the device is locked
- 🧶 Thread-Safe, Keypr is thread-safe and Swift 6 ready!
- 🧩 SwiftUI property wrapper integration, bind stored values directly to your UI

## Quickstart Guide

### Creating a Keypr Store

The `Keypr` actor is the base component that you will use to do pretty much everything else in this package. An instance of the `Keypr` actor references one file on the system, this allows you to create multiple Key Value stores.

> [!Important]
> Ensure that you only have one instance of the Keypr actor per store, two or more instances could lead to file writing issues.

You can create a `Keypr` instance in one of two ways, provding a URL and providing a Name. Though you can create an instance anywhere, it is recommended to either do it with a Dependency Injection framework, or by adding an extension to the `Keypr` type with a static property to store it.

```swift
extension Keypr {
    static let main = Keypr(name: "main") // Returns nil if the default location cannot be used.
    static let secondary = try? Keypr(path: URL(filePath: "/Path/To/File/Location")!)
}
```

#### Removing a Keypr Store

Keypr stores are file based, so to remove a store you can delete the file. `Keypr` has some static functions to make this process easier. There is a variation of this function for the two types of initializers for the `Keypr` actor.

```swift
func deleteStores() throws {
    try Keypr.removeKeypr(named: "main")
    try Keypr.removeKeypr(atPath: URL(filePath: "/Path/To/File/Location"))
}
```

### Creating Keys

Keypr uses a macro to generate type safe code to make accessing values easy and safe. To generate a key you use the `@Keyed` macro inside of an extension to the `Keypr` type. You must use Type-Annotation and provide a default value for every value.

> [!Note]
> Only values that are both `Codable` & `Sendable` are able to be stored in a Keypr store.

```swift
extension Keypr {
    @Keyed var exampleBoolean: Bool = false
    @Keyed var exampleInt: Int = 42
    @Keyed var myString: String = ""
    @Keyed var emptyValue: Double? = nil
}
```

> [!Tip]
> To provide thread-safety and prevent data races Keypr uses an actor. As a side effect, most operations done with Keypr need to happen inside of an async function.

### Reading Values

To read values from a `Keypr` store, just use the property defined with the `@Keyed` macro on the instance the value should be stored in:

```swift
func readValue() async {
    let myBool = await Keypr.main.exampleBoolean
    let myInt = await Keypr.secondary.exampleInt
}
```

### Writing Values

To write values to the storage, you call the `mutate` function off of the `Keypr` instance you want to modify. This function takes a closure where you can mutate the provided `Keypr` instance. This allows you to set many values at the same time, or just one!

```swift
func writeValue() {
    Keypr.main.mutate { k in
        k.exampleBoolean = true
        k.emptyValue = 64
    }
    // Non-async, values may not be set at this point.
}

func writeValueAsync() async {
    await Keypr.secondary.mutate { k in
        k.exampleInt = 123
    }
    // Async, waits for values to be set before continuing.
}
```

#### Deleting Values

You can remove a value from being persisted by calling the delete function through a `@Keyed` property. This will remove it from the in-memory and persisted storage. This means that the next time you try to read that property, you will receive the default value.

```swift
func deleteValue() async {
    await Keypr.main._exampleInt.delete()
}
```

### Observing Values

Keypr provides an interface to allow reactive programming with the values in a `Keypr` store. You can access a `Keypr.Stream` for any value stored. To access the `Keypr.Stream` just preface the property you are trying to read, with a `$`:

> [!Tip]
> `Keypr.Stream` is an [`AsyncSequence`](https://developer.apple.com/documentation/swift/asyncsequence) allowing easy customization of the stream of values.

> [!Note]
> A `Keypr.Stream` will always emit the latest value when you start iterating over the sequence. It will then wait for new values after.

```swift
func observeValue() async {
    let stream = await Keypr.main.$exampleInt
    for await value in stream {
        print("Example Int Is Now: \(value)")
    }
}
```

### SwiftUI Integration

Keypr provides the `@Keyp` property wrapper for usage in `SwiftUI`. This allows you to create views that use the Keypr values as state. To utilize the property wrapper, you need to provide access to a `KeyprIsolatedAccessor`, luckily this is easily accessed by reading the property prefaced with an `_`. So for the `exampleInt` property I can access its accessor through the `_exampleInt` property. 

```swift
struct ExampleView: View {
    
    @Keyp(Keypr.main._exampleBoolean) var isToggled
    @Keyp(Keypr.secondary._myString) var myString
    
    var body: some View {
        //..
    }
}
```

You can access bindings to these values using the same syntax as the `@State` property wrapper.

```swift
struct ExampleView: View {
    @Keyp(Keypr.main._exampleBoolean) var isToggled
    @Keyp(Keypr.secondary._myString) var myString
    
    var body: some View {
        VStack {
            Toggle("Am I Toggled?", isOn: $isToggled)
            TextField("My Favorite Word", text: $myString)
        }
    }
}
```

### Persisting Data

> [!Caution]
> Keypr is **NOT** a secure key value store. **NEVER** store information that needs protection.

Keypr automatically saves any changes made to its properties. It uses a 1 second debounce to prevent saves happening too frequently. You can choose to manually save the state of the store buy calling the `save` method on the `Keypr` instance you want to save. There is a standard `save` function for fire and forget operations, and an `async` version that allows you to handle any potential errors, and/or wait for the save operation to complete.

```swift
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
```

### Dynamic Values

While Keypr is focused on compile time safety, you can still use it for dynamic properties when you need to. This allows you to trade safety for flexibility when needed!

> [!Caution]
> Dynamic Values are **NOT** compile time safe. 

All of the operations done with the `@Keyed` properties can also be done with dynamic names. To do so, you use a `String` name to represent the values.

```swift
// When reading dynamic values, you must always provide a default value that can be used.
func readValue() async {
    let myDynamicBool = await Keypr.main.getValue(for: "dynBool", default: false)
    let myDynamicInt = await Keypr.secondary.getValue(for: "favNumber", default: 42)
}

func writeValue() {
    Keypr.main.mutate { k in
        k.setValue(123, for: "favNumber")
    }
    // or
    await Keypr.main.setValue(456, for: "favNumber")
}

func deleteValue() async {
    await Keypr.main.delete("favNumber")
}

func observeValue() async {
    let stream = await Keypr.main.stream(for: "dynBool", default: false)
    for await value in stream {
        print("Dynamic Bool Is Now: \(value)")
    }
}

// SwiftUI Property Wrapper
struct ExampleView: View {
    @Keyp(Keypr.main, "username") var username = "Default Value"
    
    var body: some View {
        TextField("Username:", text: $username)
    }
}
```

