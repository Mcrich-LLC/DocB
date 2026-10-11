// Test doubles for the store: a transport that serves canned responses with ETags and honours
// If-None-Match, a movable clock, and JSON builders for indexes and pages.

import Foundation
import DocBSources
import DocBStore

final class FakeTransport: @unchecked Sendable {
    struct Response { var status: Int; var body: String; var etag: String? }
    private let lock = NSLock()
    private var responses: [String: Response] = [:]
    private(set) var requests: [URLRequest] = []
    var failing = false

    func set(_ url: String, status: Int = 200, body: String = "", etag: String? = nil) {
        lock.lock(); defer { lock.unlock() }
        responses[url] = Response(status: status, body: body, etag: etag)
    }

    func remove(_ url: String) {
        lock.lock(); defer { lock.unlock() }
        responses[url] = nil
    }

    func requestCount(for url: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return requests.filter { $0.url?.absoluteString == url }.count
    }

    var transport: Transport {
        Transport { [self] request in
            let (response, failing) = lock.withLock { () -> (Response?, Bool) in
                requests.append(request)
                return (responses[request.url!.absoluteString], self.failing)
            }
            if failing { throw URLError(.notConnectedToInternet) }
            guard let response else {
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
            }
            if let etag = response.etag, request.value(forHTTPHeaderField: "If-None-Match") == etag {
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 304, httpVersion: nil, headerFields: ["ETag": etag])!)
            }
            let headers = response.etag.map { ["ETag": $0] }
            return (Data(response.body.utf8), HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: headers)!)
        }
    }
}

final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_700_000_000)
    var now: Date { lock.lock(); defer { lock.unlock() }; return current }
    func advance(_ seconds: TimeInterval) { lock.lock(); current = current.addingTimeInterval(seconds); lock.unlock() }
}

func makeLibrary(_ fake: FakeTransport, clock: Clock = Clock()) throws -> Library {
    var configuration = Configuration()
    configuration.now = { clock.now }
    configuration.concurrency = 2
    return try Library(inMemory: fake.transport, configuration: configuration)
}

/// A navigator index with one module per language whose children are the given (title, type, path) triples.
func indexJSON(_ languages: [String: [(String, String, String)]], module: String = "ExampleKit") -> String {
    let entries: String = languages.map { language, children -> String in
        let nodes: String = children.map { title, type, path -> String in
            #"{"title": "\#(title)", "type": "\#(type)", "path": "\#(path)"}"#
        }.joined(separator: ",")
        let result: String = #""\#(language)": [{"title": "\#(module)", "type": "module", "path": "/documentation/\#(module.lowercased())", "children": [{"title": "Essentials", "type": "groupMarker"}, \#(nodes)]}]"#
        return result
    }.joined(separator: ",")
    let json: String = #"{"schemaVersion": {"major": 0, "minor": 1, "patch": 2}, "interfaceLanguages": {\#(entries)}}"#
    return json
}

/// A page whose topic sections point at the given identifiers, with matching topic references.
func pageJSON(title: String, identifier: String, topics: [(String, String)] = [], role: String = "symbol") -> String {
    let identifiers: String = topics.map { (topic) -> String in #""\#(topic.0)""# }.joined(separator: ",")
    let references: String = topics.map { id, url -> String in
        let title = String(url.split(separator: "/").last ?? "")
        let result: String = #""\#(id)": {"type": "topic", "identifier": "\#(id)", "title": "\#(title)", "url": "\#(url)", "kind": "symbol", "role": "symbol"}"#
        return result
    }.joined(separator: ",")
    return """
    {"schemaVersion": {"major": 0, "minor": 3, "patch": 0},
     "identifier": {"url": "\(identifier)", "interfaceLanguage": "swift"},
     "metadata": {"title": "\(title)", "role": "\(role)"},
     "kind": "symbol",
     "sections": [],
     "topicSections": [{"title": "Topics", "identifiers": [\(identifiers)]}],
     "references": {\(references)}}
    """
}

let base = URL(string: "https://example.com/docs")!
let docc = Source(base: base, kind: .docc, title: "Example Kit", languages: ["swift"])

extension AsyncThrowingStream where Element == SyncEvent, Failure == any Error {
    func collect() async throws -> [SyncEvent] {
        var events: [SyncEvent] = []
        for try await event in self { events.append(event) }
        return events
    }
}
