// The one seam between this package and the network: a closure from request to response.
// Production wraps URLSession; tests hand in a dictionary keyed by URL.

import Foundation

/// Fetches HTTP resources. Non-2xx responses are returned, not thrown, so callers decide what a miss means.
public struct Transport: Sendable {
    public var fetch: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public init(fetch: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.fetch = fetch
    }

    /// A transport backed by a URL session.
    public static func urlSession(_ session: URLSession = .shared) -> Transport {
        Transport { request in
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TransportError.notHTTP(request.url)
            }
            return (data, http)
        }
    }
}

/// A transport failure that is not an HTTP status.
public enum TransportError: Error, Equatable {
    /// The response was not an HTTP response, for example for a file URL.
    case notHTTP(URL?)
}
