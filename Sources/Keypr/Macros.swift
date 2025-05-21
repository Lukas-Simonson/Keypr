//
//  Macros.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/20/25.
//

@attached(accessor)
@attached(peer, names: prefixed(__Key_), prefixed(`$`))
public macro Keyed() = #externalMacro(module: "Keyed", type: "KeyedMacro")
