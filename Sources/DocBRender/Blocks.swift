// Blocks of the page that are SwiftUI views rather than text: a card grid, later tables and
// the like. Each is one attachment in the text, so the page flows around it, and a hosted
// view placed over the attachment once laid out, as images are. The document sizes it by
// asking a hosting controller what height the view wants at the column's width, and again
// whenever the width changes or a picture arrives. The views get what they need from the
// environment: where links go, and the page's images.

import DocBPage
import SwiftUI
#if canImport(AppKit)
import AppKit
typealias PlatformHostingController = NSHostingController<AnyView>
#else
import UIKit
typealias PlatformHostingController = UIHostingController<AnyView>
#endif

final class BlockAttachment: NSTextAttachment {
    /// The block's view for a width, which is the column's less the indent: a view that lays
    /// itself out differently narrow (a grid's columns) is told the width, not left to find it.
    let content: (CGFloat) -> AnyView
    /// What the column's width loses to the block's sides: its paragraph's indent, and the
    /// trailing space a box around it keeps.
    let insets: CGFloat

    init(insets: CGFloat, content: @escaping (CGFloat) -> some View) {
        self.content = { AnyView(content($0)) }
        self.insets = insets
        super.init(data: nil, ofType: nil)
        bounds = .zero
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The block's size, which the page sets from the column width.
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        bounds
    }
}

extension EnvironmentValues {
    /// Where a link in a hosted block goes: the page model's reference, for the host to resolve.
    @Entry var openPageLink: (String) -> Void = { _ in }
}

/// The page's images for its hosted views: fetched through the page's loader, decoded and
/// cached as the text's images are, and observed, so a view draws its picture when it arrives.
@MainActor @Observable
final class PageImages {
    var dark = false { didSet { if dark != oldValue { started = [] } } }
    @ObservationIgnored var loader: ImageLoader = defaultImageLoader
    /// Runs when a picture has arrived, for the document to size its blocks again.
    @ObservationIgnored var arrived: (() -> Void)?
    private var decoded: [String: DecodedImage] = [:]
    @ObservationIgnored private var started: Set<String> = []

    /// The picture for a media, at the current appearance, or nil until it has arrived.
    func image(for media: Media?) -> DecodedImage? {
        guard let media, let variant = media.variant(dark: dark) else { return nil }
        if let image = decoded[variant.url] ?? ImageCache.image(for: variant.url) { return image }
        guard !started.contains(variant.url) else { return nil }
        started.insert(variant.url)
        let loader = loader
        Task { @MainActor [weak self] in
            guard let data = await loader(variant.url) else { return }
            let image = await Task.detached { DecodedImage.decode(data, scale: variant.scale, maxPixels: ImageCache.maxPixels) }.value
            guard let image, let self else { return }
            ImageCache.store(image, for: variant.url)
            decoded[variant.url] = image
            arrived?()
        }
        return nil
    }
}
