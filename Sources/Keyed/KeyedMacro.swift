//
//  Keyed.swift
//  Keypr
//
//  Created by Lukas Simonson on 5/20/25.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion

public struct KeyedMacro {
    
}

extension KeyedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let extensionType = context.lexicalContext.first?
            .as(ExtensionDeclSyntax.self)?.extendedType
            .as(IdentifierTypeSyntax.self)
        guard extensionType?.name.text == "Keypr" else {
            throw MacroExpansionErrorMessage("Resolved macro must be applied to Keypr")
        }
        
        guard let identifier = declaration.as(VariableDeclSyntax.self)?.bindings.first?.pattern else {
            throw MacroExpansionErrorMessage("Unable to resolve variable identifier")
        }
        
        let getAccessor = AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
            "self[__Key_\(identifier).self]"
        }
        let setAccessor = AccessorDeclSyntax(accessorSpecifier: .keyword(.set)) {
            "self[__Key_\(identifier).self] = newValue"
        }
        return [getAccessor, setAccessor]
    }
}

extension KeyedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let initialValue = binding.initializer?.value else {
            throw MacroExpansionErrorMessage("Expected a var with an initializer")
        }
        
        let keyName = "__Key_\(identifier)"
        
        guard let type = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        else { throw MacroExpansionErrorMessage("@Keyed properties must have an explicit type.") }
        
        return [
            
            // IsolatedAccessor Macro
            """
            nonisolated var _\(raw: identifier): KeyprIsolatedAccessor<\(raw: type)> {
                KeyprIsolatedAccessor(
                    defaultValue: \(raw: keyName).defaultValue,
                    isolatedTo: self,
                    getter: { $0[\(raw: keyName).self] },
                    setter: { $0[\(raw: keyName).self] = $1 },
                    publisher: { $0.publisher(for: \(raw: keyName).self) }
                )
            }
            """,
            
            // Publisher Macro
            """
            var $\(raw: identifier): AnyPublisher<\(raw: type), Never> {
                publisher(for: \(raw: keyName).self)
            }
            """,
            
            // Private key struct
            """
            private struct \(raw: keyName): KeyprKey {
                static let name = "\(raw: identifier)"
                static let defaultValue: \(raw: type) = \(initialValue)
            }
            """
        ]
    }
}
