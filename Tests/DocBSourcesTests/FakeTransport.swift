// A transport that serves canned bodies by URL and answers 404 to everything else, recording
// every request so tests can assert on probe order.

import Foundation
import DocBSources

final class FakeTransport: @unchecked Sendable {
    var bodies: [URL: String]
    private(set) var requested: [URL] = []

    init(_ bodies: [String: String]) {
        self.bodies = Dictionary(uniqueKeysWithValues: bodies.map { (URL(string: $0)!, $1) })
    }

    var transport: Transport {
        Transport { [self] request in
            let url = request.url!
            requested.append(url)
            let status = bodies[url] == nil ? 404 : 200
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data((bodies[url] ?? "").utf8), response)
        }
    }
}

/// A minimal catalog node with the given technology entries, each `(title, destination, languages)`.
func catalogJSON(_ technologies: [(String, String, [String])]) -> String {
    let entries = technologies.map { title, destination, languages in
        """
        {"title": "\(title)", "content": [], "languages": [\(languages.map { "\"\($0)\"" }.joined(separator: ","))],
         "tags": ["Example Tag"],
         "destination": {"type": "reference", "identifier": "\(destination)", "isActive": true}}
        """
    }.joined(separator: ",")
    return """
    {"schemaVersion": {"major": 0, "minor": 3, "patch": 0},
     "identifier": {"url": "doc://com.example/documentation/technologies", "interfaceLanguage": "swift"},
     "metadata": {"title": "Technologies", "role": "overview"},
     "kind": "technologies",
     "sections": [{"kind": "technologies", "groups": [{"name": "Example Group", "technologies": [\(entries)]}]}],
     "references": {}}
    """
}

/// A minimal navigator index with one module per title, per language.
func indexJSON(languages: [String: [String]]) -> String {
    let entries = languages.map { language, titles in
        let nodes = titles.map { "{\"title\": \"\($0)\", \"type\": \"module\", \"path\": \"/documentation/\($0.lowercased())\"}" }
        return "\"\(language)\": [\(nodes.joined(separator: ","))]"
    }.joined(separator: ",")
    return """
    {"schemaVersion": {"major": 0, "minor": 1, "patch": 2},
     "interfaceLanguages": {\(entries)},
     "includedArchiveIdentifiers": ["com.example.ExampleKit"]}
    """
}

/// A minimal build metadata file.
func metadataJSON(name: String) -> String {
    #"{"bundleDisplayName": "\#(name)", "bundleIdentifier": "com.example.\#(name)", "schemaVersion": {"major": 0, "minor": 1, "patch": 0}}"#
}

/// A minimal symbol page for an index-less site.
func pageJSON(identifier: String) -> String {
    """
    {"schemaVersion": {"major": 0, "minor": 2, "patch": 0},
     "identifier": {"url": "\(identifier)", "interfaceLanguage": "swift"},
     "metadata": {"title": "Example Kit", "role": "collection"},
     "kind": "symbol",
     "sections": [],
     "references": {}}
    """
}
