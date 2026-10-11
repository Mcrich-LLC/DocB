// Page bodies are stored lzfse-compressed. SQLite never looks inside them.

import Foundation

enum Compression {
    static func compress(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .lzfse) as Data
    }

    static func decompress(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .lzfse) as Data
    }
}
