// Resolver tests: every spelling of a page (identifier, absolute URL, relative URL, data file)
// normalizes to the same location; fragments and queries are split off; other hosts are
// external; web and asset URLs resolve against the base.

import Foundation
import Testing
@testable import DocBSources

@Suite struct PageLocationTests {
    let base = URL(string: "https://example.com/owner/pkg/main")!
    var source: Source { Source(base: base, kind: .docc, title: "Example Kit", languages: ["swift"]) }
    var expected: PageLocation { PageLocation(base: base, path: "documentation/examplekit/thing") }

    @Test func identifierKeepsItsPathAndDropsTheBundle() {
        #expect(source.location(for: "doc://com.example.ExampleKit/documentation/ExampleKit/Thing") == expected)
    }

    @Test func absoluteURLOnTheBaseIsStripped() {
        #expect(source.location(for: "https://example.com/owner/pkg/main/documentation/examplekit/thing") == expected)
        #expect(source.location(for: "HTTPS://EXAMPLE.COM/owner/pkg/main/documentation/ExampleKit/Thing/") == expected)
    }

    @Test func relativeURLIsBaseRelative() {
        #expect(source.location(for: "/documentation/examplekit/thing") == expected)
        #expect(source.location(for: "documentation/examplekit/thing") == expected)
    }

    @Test func dataFileSpellingDropsTheExtension() {
        #expect(source.location(for: "/data/documentation/examplekit/thing.json")?.path == "data/documentation/examplekit/thing")
        #expect(source.location(for: "/documentation/examplekit/thing.json") == expected)
    }

    @Test func fragmentAndQueryAreSplitOff() {
        let location = source.location(for: "doc://com.example/documentation/ExampleKit/Thing#Topics?language=objc")
        #expect(location?.path == "documentation/examplekit/thing")
        #expect(location?.fragment == "Topics?language=objc")
        let queried = source.location(for: "/documentation/examplekit/thing?language=objc#Overview")
        #expect(queried?.path == "documentation/examplekit/thing")
        #expect(queried?.fragment == "Overview")
    }

    @Test func percentEncodedAndSpecialPathsDecode() {
        #expect(source.location(for: "https://example.com/owner/pkg/main/documentation/examplekit/thing/init(_:_:)")?.path == "documentation/examplekit/thing/init(_:_:)")
        #expect(source.location(for: "/documentation/examplekit/thing/init(_:_:)")?.path == "documentation/examplekit/thing/init(_:_:)")
        #expect(source.location(for: "/documentation/examplekit/nsobject-swift.class")?.path == "documentation/examplekit/nsobject-swift.class")
    }

    @Test func rootPageWithoutModuleIsFine() {
        #expect(source.location(for: "/documentation")?.path == "documentation")
        #expect(source.location(for: "/tutorials/examplekit/first-steps")?.path == "tutorials/examplekit/first-steps")
    }

    @Test func otherHostIsExternal() {
        #expect(source.location(for: "https://elsewhere.example.com/documentation/x") == nil)
        #expect(source.location(for: "https://example.com/other/documentation/x") == nil)
    }

    @Test func webURLIncludesFragment() {
        let location = PageLocation(base: base, path: "documentation/examplekit/thing", fragment: "Overview")
        #expect(source.webURL(for: location).absoluteString == "https://example.com/owner/pkg/main/documentation/examplekit/thing#Overview")
        #expect(source.webURL(for: expected).absoluteString == "https://example.com/owner/pkg/main/documentation/examplekit/thing")
    }

    @Test func assetURLsAreBaseRelativeUnlessAbsolute() {
        #expect(source.assetURL(for: "/images/com.example.ExampleKit/logo@2x.png").absoluteString == "https://example.com/owner/pkg/main/images/com.example.ExampleKit/logo@2x.png")
        #expect(source.assetURL(for: "https://cdn.example.com/logo.png").absoluteString == "https://cdn.example.com/logo.png")
        let apple = Source(base: URL(string: "https://developer.apple.com")!, kind: .appleDeveloper(module: "swiftui"), title: "SwiftUI", languages: ["swift"])
        #expect(apple.assetURL(for: "/images/com.apple.SwiftUI/hero@2x.png").absoluteString == "https://developer.apple.com/tutorials/images/com.apple.SwiftUI/hero@2x.png")
    }

    @Test func appleDeveloperDataURLIsCaseInsensitiveByLowercasing() {
        let apple = Source(base: URL(string: "https://example.com")!, kind: .appleDeveloper(module: "examplekit"), title: "", languages: [])
        let location = apple.location(for: "doc://com.example.documentation/documentation/ExampleKit/Thing")!
        #expect(apple.dataURL(for: location).absoluteString == "https://example.com/tutorials/data/documentation/examplekit/thing.json")
    }
}
