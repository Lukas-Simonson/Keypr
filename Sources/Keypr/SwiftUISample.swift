//
//  SwiftUISample.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/21/25.
//

import SwiftUI

extension Keypr {
    @Keyed var isKeyed: Bool = false
    @Keyed var keyedText: String = ""
}

extension Keypr {
    static let main = Keypr(name: "main2")!
}

struct SampleView: View {
    
    @Keyp(Keypr.main._isKeyed) var isKeyed
    @Keyp(Keypr.main._keyedText) var keyedText
    
    @Keyp(Keypr.main, "is_dynamic") var isDynamic = false
    @Keyp(Keypr.main, "dynamic_text") var dynamicText = ""
    
    var body: some View {
        VStack {
            Toggle(
                isOn: $isKeyed,
                label: { Text("Is Keyed") }
            )
            
            TextField(
                "Keyed Text",
                text: $keyedText
            )
            
            Toggle(
                isOn: $isDynamic,
                label: { Text("Is Dynamic") }
            )
            
            TextField(
                "Dynamic Text",
                text: $dynamicText
            )
        }
    }
}


//
//struct SampleView: View {
//    
//    @Keyp(
//        Keypr.main,
//        value: \.isKeyed,
//        publisher: \.$isKeyed
//    ) var isKeyed
//    
//    @Keyp(
//        Keypr.main,
//        value: \.keyedText,
//        publisher: \.$keyedText
//    ) var keyedText
//    
//    @Keyp(Keypr.main, "is_dynamic") var isDynamic = false
//    @Keyp(Keypr.main, "dynamic_text") var dynamicText = ""
//
//}
//
#Preview {
    SampleView()
}
