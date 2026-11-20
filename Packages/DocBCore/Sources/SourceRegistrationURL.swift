import Foundation

/// Extracts the source URL from a registration link.
enum SourceRegistrationURL {
    static func matches(_ url: URL) -> Bool {
        url.host?.lowercased() == "register" || url.path.hasPrefix("/register/") || url.path == "/register"
    }

    static func sourceURL(from link: URL) throws -> URL {
        guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var payload = components.percentEncodedPath
        if link.host?.lowercased() == "register" {
            payload = String(payload.dropFirst())
        } else if payload.hasPrefix("/register/") {
            payload = String(payload.dropFirst("/register/".count))
        } else {
            throw URLError(.badURL)
        }
        if let query = components.percentEncodedQuery { payload += "?" + query }
        if let fragment = components.percentEncodedFragment { payload += "#" + fragment }

        // Decode an encoded URL once, preserving escapes in URLs supplied verbatim.
        if !payload.contains("://") {
            payload = payload.removingPercentEncoding ?? payload
        }
        if !payload.contains("://") {
            payload = "https://\(payload)"
        }
        guard let url = URL(string: payload) else { throw URLError(.badURL) }
        return url
    }
}
