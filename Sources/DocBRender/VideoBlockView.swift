// A video in the page, as the web shows it: its poster with a play button until it is asked
// to play, then the system player in the same place. The bytes come through the page's
// loader like an image's, and go to a file for the player, which streams from files only.

import AVKit
import CryptoKit
import DocBPage
import SwiftUI

struct VideoBlockView: View {
    let media: Media
    let poster: Media?
    @Environment(PageImages.self) private var images
    @State private var player: AVPlayer?
    @State private var loading = false

    var body: some View {
        let posterImage = images.image(for: poster)
        Group {
            if let player {
                #if os(macOS)
                PlayerView(player: player)
                #else
                VideoPlayer(player: player)
                #endif
            } else {
                Color.black.opacity(0.85)
                    .overlay { if let posterImage { posterImage.swiftUIImage.resizable().scaledToFill() } }
                    .overlay {
                        if loading {
                            ProgressView().controlSize(.large).tint(.white)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { play() }
                    .accessibilityLabel(media.alt ?? "Video")
                    .accessibilityAddTraits(.isButton)
                    #if os(macOS)
                    .pointerStyle(.link)
                    #endif
            }
        }
        // As wide as the poster, or the column; at the poster's shape, or 16:9 until it comes.
        .aspectRatio(posterImage.map { $0.pointSize.width / $0.pointSize.height } ?? 16 / 9, contentMode: .fit)
        .frame(maxWidth: posterImage?.pointSize.width)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func play() {
        guard !loading, let variant = media.variant(dark: images.dark) else { return }
        loading = true
        let loader = images.loader
        Task {
            defer { loading = false }
            guard let data = await loader(variant.url), let url = MediaFile.url(for: variant.url, data: data, fallbackExtension: "mp4") else { return }
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
    }
}

/// Where a video's bytes go for the player: a file in the temporary directory named by the
/// reference, written once.
/// Media bytes as a temporary file, for the players and viewers that read files only.
enum MediaFile {
    static func url(for reference: String, data: Data, fallbackExtension: String) -> URL? {
        let name = SHA256.hash(data: Data(reference.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let ext = (reference as NSString).pathExtension.isEmpty ? fallbackExtension : (reference as NSString).pathExtension
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("docb-media-\(name).\(ext)")
        if !FileManager.default.fileExists(atPath: url.path) {
            do { try data.write(to: url) } catch { return nil }
        }
        return url
    }
}
