//
//  Plugin.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/20/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct KeyedPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [KeyedMacro.self]
}
