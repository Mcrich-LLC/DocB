// The download button on a sample code page, under the abstract as the web puts it. The
// page's host resolves where the download lives and opens it outside the app.

import DocBPage
import SwiftUI

struct DownloadButtonView: View {
    let download: Download
    @Environment(\.openPageLink) private var openPageLink

    var body: some View {
        Button {
            openPageLink(download.url)
        } label: {
            Label(download.title, systemImage: "arrow.down.circle")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        #if os(macOS)
        .pointerStyle(.link)
        #endif
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
