// The web renderer's highlighter, run here: highlight.js in JavaScriptCore, bundled with the
// languages, aliases and custom grammars of swift-docc-render, so a listing gets the tokens
// it gets on developer.apple.com. A language it does not know is one plain token.

import Foundation
import JavaScriptCore

@MainActor
public enum Highlighter {
    /// The listing's tokens, in order, covering all of its text.
    public static func tokens(for code: String, language: String?) -> [SyntaxToken] {
        guard let function = context.objectForKeyedSubscript("docbHighlight"),
              let result = function.call(withArguments: [code, language ?? ""]).toArray() as? [[Any]] else {
            return [SyntaxToken(code)]
        }
        return result.compactMap { pair in
            guard pair.count == 2, let text = pair[0] as? String else { return nil }
            return SyntaxToken(text, scopes: pair[1] as? [String] ?? [])
        }
    }

    // ponytail: made on first use, on the main thread, a few tens of milliseconds; warm it up
    // off the main thread at launch if a first listing ever shows a hitch.
    private static let context: JSContext = {
        let context = JSContext()!
        context.exceptionHandler = { _, exception in
            assertionFailure("highlight: \(exception?.toString() ?? "?")")
        }
        let url = Bundle.module.url(forResource: "highlight.min", withExtension: "js")!
        context.evaluateScript(try! String(contentsOf: url, encoding: .utf8))
        return context
    }()
}
