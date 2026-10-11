// Images in the page: each image block is a SwiftUI block that draws its picture once the
// bytes arrive. The host hands the bytes over by reference (a path relative to the page's
// source, or an absolute URL) through a loader, so the renderer knows nothing about where
// pages come from; without a loader, absolute URLs are fetched with URLSession and the rest
// are left blank. Decoding downsamples to what the page can show, as the web serves images
// at the display's density and no larger.

import DocBPage
import ImageIO
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// The bytes for a media reference, or nil when there are none to be had.
public typealias ImageLoader = @Sendable (String) async -> Data?

/// The loader used when the host gives none: absolute URLs through the shared session, which
/// keeps the system's HTTP cache; references relative to a source cannot be resolved here.
public let defaultImageLoader: ImageLoader = { reference in
    guard reference.contains("://"), let url = URL(string: reference) else { return nil }
    return try? await URLSession.shared.data(from: url).0
}

/// A decoded image and the size it is meant to be shown at, in points, with the bytes it came
/// from so it can be copied, dragged and saved as the file it is.
struct DecodedImage: Sendable {
    let cgImage: CGImage
    let pointSize: CGSize
    let data: Data

    /// Decodes bytes, sized as the variant's scale says and downsampled to at most `maxPixels`
    /// across, which is as many as a page column can show. ImageIO produces the thumbnail
    /// straight from the file, so a large image never has to be decoded at full size.
    static func decode(_ data: Data, scale: Int, maxPixels: Int) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat, let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let scale = CGFloat(max(1, scale))
        return DecodedImage(cgImage: image, pointSize: CGSize(width: width / scale, height: height / scale), data: data)
    }

    /// The picture as a SwiftUI image at its point size.
    var swiftUIImage: Image {
        Image(cgImage, scale: CGFloat(cgImage.width) / pointSize.width, label: Text(""))
    }
}

extension Media {
    /// The variant for an appearance: the matching one at 2x if there is one, else the
    /// sharpest, falling back to the other appearance's when there is none.
    func variant(dark: Bool) -> Variant? {
        let matching = variants.filter { $0.isDark == dark }
        let candidates = matching.isEmpty ? variants : matching
        return candidates.first { $0.scale == 2 } ?? candidates.max { $0.scale < $1.scale }
    }
}

/// Decoded images by reference, shared by every page so a page shows its images at once when
/// the reader comes back to it. Downsampled at decode, so entries stay small.
@MainActor
enum ImageCache {
    private static let cache: NSCache<NSString, Entry> = { let cache = NSCache<NSString, Entry>(); cache.totalCostLimit = 96 << 20; return cache }()
    private final class Entry { let image: DecodedImage; init(_ image: DecodedImage) { self.image = image } }
    /// Twice the widest column, as many pixels as an image can ever show here.
    nonisolated static let maxPixels = 1520

    static func image(for reference: String) -> DecodedImage? { cache.object(forKey: reference as NSString)?.image }
    static func store(_ image: DecodedImage, for reference: String) {
        cache.setObject(Entry(image), forKey: reference as NSString, cost: image.data.count + image.cgImage.bytesPerRow * image.cgImage.height)
    }
}

// MARK: - The image block

/// An image at its own size or the column's, centered in it as the web shows it: nothing until
/// it arrives. It names itself to assistive technology, drags out, offers Copy and Save in its
/// menu, and opens at full size in Quick Look when clicked. No tooltip: one anywhere in the
/// page has AppKit ask SwiftUI what lies under the pointer on every scroll frame, and the
/// answer hit-tests every block on the page.
struct ImageBlockView: View {
    let media: Media
    @Environment(PageImages.self) private var images
    @State private var preview: URL?

    var body: some View {
        if let image = images.image(for: media) {
            let file = ImageFile(image: image, media: media)
            image.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: image.pointSize.width)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(media.alt ?? "")
                .accessibilityAddTraits(.isButton)
                .onTapGesture { preview = file.url }
                .quickLookPreview($preview)
                .draggable(file)
                .contextMenu {
                    Button("Open Image") { preview = file.url }
                    Button("Copy Image") { file.copy() }
                    #if os(macOS)
                    Button("Save Image As…") { file.save() }
                    #endif
                }
        }
    }
}

/// An image as the file it came from, for the pasteboard, dragging and saving.
struct ImageFile: Transferable {
    let image: DecodedImage
    let media: Media

    /// The file's name and type, as the host names it.
    var name: String { media.variants.first.flatMap { URL(string: $0.url)?.lastPathComponent } ?? "image.png" }
    var type: UTType { UTType(filenameExtension: (name as NSString).pathExtension) ?? .png }
    /// The full-size bytes as a file, for Quick Look.
    var url: URL? { MediaFile.url(for: name, data: image.data, fallbackExtension: "png") }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { file in file.image.data }
        DataRepresentation(exportedContentType: .jpeg) { file in file.image.data }
        DataRepresentation(exportedContentType: .image) { file in file.image.data }
    }

    @MainActor func copy() {
        #if os(macOS)
        guard let image = NSImage(data: self.image.data) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        #else
        UIPasteboard.general.image = UIImage(data: self.image.data)
        #endif
    }

    #if os(macOS)
    @MainActor func save() {
        guard let window = NSApp.keyWindow else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try image.data.write(to: url) } catch { window.presentError(error) }
        }
    }
    #endif
}
