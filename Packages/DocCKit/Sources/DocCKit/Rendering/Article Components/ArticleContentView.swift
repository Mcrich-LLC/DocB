//
//  ArticleContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//
// swiftlint:disable type_body_length

import SwiftUI
import NukeUI
import AVKit
import HighlightSwift

/// Pre-rendered inline content segment used by `InlineContentView`.
fileprivate struct ArticleInlineContent: Identifiable {
    /// Stable identifier for ordered inline view composition.
    let id: Int
    
    /// Concrete inline segment payload.
    let kind: Kind
    
    /// Inline segment variants.
    enum Kind {
        case text(AttributedString)
        case image(identifier: String, abstract: [ContentStruct])
        case video(identifier: String)
    }
    
    /// Creates a text segment.
    ///
    /// - Parameters:
    ///   - text: Attributed text to render.
    ///   - id: Stable identifier for this render pass.
    static func text(_ text: AttributedString, id: Int) -> Self {
        .init(id: id, kind: .text(text))
    }
    
    /// Creates an image segment.
    ///
    /// - Parameters:
    ///   - id: Stable identifier for this render pass.
    ///   - identifier: Reference identifier for the image.
    ///   - abstract: Optional caption content.
    static func image(id: Int, identifier: String, abstract: [ContentStruct]) -> Self {
        .init(id: id, kind: .image(identifier: identifier, abstract: abstract))
    }
    
    /// Creates a video segment.
    ///
    /// - Parameters:
    ///   - id: Stable identifier for this render pass.
    ///   - identifier: Reference identifier for the video.
    static func video(id: Int, identifier: String) -> Self {
        .init(id: id, kind: .video(identifier: identifier))
    }
}

/// Coordinates content transformation and style decisions used while rendering article content blocks.
@Observable
private class ArticleContentManager {
    /// The content node currently being rendered.
    var content: ContentSection.Content
    /// Reference metadata keyed by identifier for inline links and media.
    var references: [String : Reference]
    /// The parent content type, used for context-sensitive formatting.
    var type: ContentType?
    /// Horizontal/vertical alignment used for rendered child views.
    var alignment: Alignment
    /// The current ordered-list index used when formatting list prefixes.
    var orderedListIndex: Int
    /// Selected image metadata used to present the enlarged image sheet.
    var enlargedImageSheetIdentifier: EnlargedImageSheetIdentifier?
    /// Cached inline render output keyed by source content and deep-link scheme.
    @ObservationIgnored private var inlineContentCache: [InlineContentCacheKey : [ArticleInlineContent]] = [:]
    
    /// Creates a manager for rendering a single content node.
    ///
    /// - Parameters:
    ///   - content: The content node to render.
    ///   - references: Reference metadata for identifiers used by this content subtree.
    ///   - type: The parent content type, if available.
    ///   - alignment: Desired alignment for generated views.
    ///   - orderedListIndex: Current index for ordered-list formatting.
    init(content: ContentSection.Content, references: [String : Reference], type: ContentType? = nil, alignment: Alignment, orderedListIndex: Int) {
        self.content = content
        self.references = references
        self.type = type
        self.alignment = alignment
        self.orderedListIndex = orderedListIndex
    }
    
    /// Returns an attributed string with list-specific prefixes when the content type requires it.
    func specialStyleString(_ string: String, type: ContentType? = nil, orderedListIndex: Int? = nil) -> AttributedString {
        let type = type ?? self.type
        let orderedListIndex = orderedListIndex ?? self.orderedListIndex
        
        switch type {
        case .unorderedList:
            var bulletString = AttributedString(" • ")
            bulletString.foregroundColor = Color.primary
            
            return bulletString + AttributedString(string)
        case .orderedList:
            var numberString = AttributedString(" \(orderedListIndex). ")
            numberString.foregroundColor = Color.primary
            
            return numberString + AttributedString(string)
        default:
            return AttributedString(string)
        }
    }
    
    /// Resolves a displayable image or video URL for a reference identifier and current appearance.
    func fetchPhotoVideoURL(for identifier: String, colorScheme: ColorScheme, docCSite: DocCSource?) -> URL? {
        guard let url = DocCAssetResolver.fetchPhotoVideoURL(for: identifier, references: references, colorScheme: colorScheme, docCSite: docCSite) else {
            return nil
        }
        
        guard url.host() == nil else {
            return url
        }
        
        let fullUrl = docCSite?.url.appending(path: url.path())
        
        return fullUrl
    }
    
    /// Builds attributed reference text for a documentation identifier, including link styling when possible.
    func getReferenceText(for identifier: String, tintColor: Color?, deepLinkScheme: DocCDeepLinkScheme) -> AttributedString? {
        guard let reference = references[identifier], let title = reference.title else {
            return nil
        }
        
        let attributes: [NSAttributedString.Key: Any]
        
        if let url = URL(string: deepLinkScheme.urlString(forDocIdentifier: identifier)) {
            let role = reference.role ?? .article
            
            if role == .symbol {
                attributes = [
                    .foregroundColor: tintColor ?? PlatformColor.accent,
                    .font: PlatformFont.monospacedSystemFont(ofSize: PlatformFont.labelFontSize, weight: .medium),
                    .underlineStyle : 0,
                    .link: url
                ]
            } else {
                attributes = [
                    .foregroundColor: tintColor ?? PlatformColor.accent,
                    .underlineStyle : 0,
                    .link: url
                ]
            }
        } else {
            attributes = [:]
        }
        
        let attributedString = NSAttributedString(string: title, attributes: attributes)
        
        return AttributedString(attributedString)
    }
    
    /// Flattens emphasis content into a plain display string.
    func getEmphasisString(_ content: ContentStruct) -> String {
        var string = ""
        
        for inContent in [content] + (content.inlineContent ?? []) {
            switch inContent.type {
            case .text:
                if let text = inContent.text {
                    string.append(text)
                }
            case .codeVoice:
                if let code = inContent.code {
                    string.append(code)
                }
            default:
                if let text = inContent.text {
                    string.append(text)
                }
            }
        }
        
        return string
    }
    
    /// Returns attributed, code-styled text for a single inline content node.
    func getCodeString(_ content: ContentStruct) -> AttributedString {
        return getCodeString([content.code ?? ""])
    }
    
    /// Returns attributed, code-styled text for one or more code lines.
    func getCodeString(_ content: [String]) -> AttributedString {
        var strings = ""
        
        for subcontent in content {
            strings.append(subcontent)
        }
        
        #if os(macOS)
        let attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: PlatformColor.controlBackgroundColor
        ]
        #else
        let attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: PlatformColor.secondarySystemBackground
        ]
        #endif
        
        let attributedString = NSAttributedString(string: strings, attributes: attributes)
        
        return AttributedString(attributedString)
    }
    
    /// Returns pre-rendered inline content segments for the given content.
    func inlineContentSegments(for content: [ContentStruct], tintColor: Color?, deepLinkScheme: DocCDeepLinkScheme, docCSource: DocCSource?) -> [ArticleInlineContent] {
        let key = InlineContentCacheKey(content: content, deepLinkScheme: deepLinkScheme)
        
        if let cachedContent = inlineContentCache[key] {
            return cachedContent
        }
        
        let renderedContent = buildInlineContentSegments(for: content, tintColor: tintColor, deepLinkScheme: deepLinkScheme, docCSource: docCSource)
        inlineContentCache[key] = renderedContent
        
        return renderedContent
    }
    
    /// Builds inline content segments from raw DocC inline fragments.
    private func buildInlineContentSegments(for content: [ContentStruct], tintColor: Color?, deepLinkScheme: DocCDeepLinkScheme, docCSource: DocCSource?) -> [ArticleInlineContent] {
        var views: [ArticleInlineContent] = []
        var nextInlineID = 0
        var text = specialStyleString("", type: .text)
        
        func nextID() -> Int {
            defer { nextInlineID += 1 }
            
            return nextInlineID
        }
        
        func appendText() {
            guard text != AttributedString("") else { return }
            
            views.append(.text(text, id: nextID()))
            text = specialStyleString("", type: .text)
        }
        
        // swiftlint:disable:next cyclomatic_complexity
        func appendContent(_ content: [ContentStruct]) {
            let firstNonEmptyTextID = content.first { !($0.text ?? "").isEmpty }?.id
            
            for inline in content {
                switch inline.type {
                case .text, .orderedList, .unorderedList, .paragraph, .heading:
                    let inlineText: String
                    
                    if let text = inline.text {
                        inlineText = text
                    } else if let text = inline.code {
                        inlineText = text
                    } else if let identifier = inline.identifier {
                        if let reference = references[identifier], let title = reference.title {
                            inlineText = title
                        } else {
                            inlineText = String(identifier.split(separator: "/").last?.split(separator: "-").first ?? "").capitalized
                        }
                    } else {
                        inlineText = ""
                    }
                    
                    if !(inline.text == " " && firstNonEmptyTextID == inline.id) {
                        var attributedString = specialStyleString(inlineText, type: inline.type, orderedListIndex: inline.orderedListInt)
                        
                        if let font = inline.font?.font {
                            if let weight = inline.fontWeight?.fontWeight {
                                attributedString.font = font.weight(weight)
                            } else {
                                attributedString.font = font
                            }
                        } else if let weight = inline.fontWeight?.fontWeight {
                            attributedString.font = .body.weight(weight)
                        }
                        
                        if let identifier = inline.identifier {
                            var reference = references[identifier]
                            if reference?.docCSite == nil {
                                reference?.docCSite = docCSource
                            }
                            
                            if let reference, let url = reference.externalURL {
                                attributedString.link = url
                            } else {
                                attributedString.link = URL(string: identifier)
                            }
                        }
                        
                        if inlineText == "/%1.5_break_/%" {
                            attributedString = AttributedString("\n\n")
                            attributedString.font = .system(size: 2)
                        }
                        
                        text += attributedString
                    }
                case .codeVoice:
                    text += getCodeString(inline)
                case .emphasis:
                    if inline.inlineContent?.isAllSomeFormOfText == true {
                        text += inline.getFlattenedAttributedString()
                        continue
                    }
                    
                    let string = getEmphasisString(inline)
                    var attributedString = AttributedString(string)
                    attributedString.font = .body.italic()
                    
                    text += attributedString
                case .strong:
                    if inline.inlineContent?.isAllSomeFormOfText == true {
                        text += inline.getFlattenedAttributedString()
                        continue
                    }
                    
                    let string = getEmphasisString(inline)
                    var attributedString = AttributedString(string)
                    attributedString.font = .body.bold()
                    
                    text += attributedString
                case .reference:
                    if let identifier = inline.identifier,
                       let referenceText = getReferenceText(for: identifier, tintColor: tintColor, deepLinkScheme: deepLinkScheme) {
                        text += referenceText
                    }
                case .image:
                    appendText()
                    
                    if let identifier = inline.identifier {
                        views.append(.image(id: nextID(), identifier: identifier, abstract: inline.metadata?.abstract ?? []))
                    }
                case .video:
                    appendText()
                    
                    if let identifier = inline.identifier {
                        views.append(.video(id: nextID(), identifier: identifier))
                    }
                default:
                    break
                }
                
                if let inlineContent = inline.inlineContent {
                    appendContent(inlineContent)
                }
            }
        }
        
        appendContent(content)
        
        if text != AttributedString("") {
            appendText()
        }
        
        return views
    }
    
    /// Cache key for inline render output that is independent of layout size.
    private struct InlineContentCacheKey: Hashable {
        /// Raw inline content fragments being rendered.
        let content: [ContentStruct]
        /// Deep-link scheme used when constructing attributed reference links.
        let deepLinkScheme: DocCDeepLinkScheme
    }
}

/// Renders a single documentation content node and recursively renders nested child content.
struct ArticleContentView: View {
    /// Shared renderer state for this content node and its descendants.
    @State private var manager: ArticleContentManager
    @Environment(\.docCSite) var docCSite
    @Environment(\.docCTintColor) var tintColor
    @Environment(\.docCDeepLinkScheme) private var deepLinkScheme
    
    /// Creates a content renderer for a content node and its references.
    init(content: ContentSection.Content, references: [String : Reference], from type: ContentType? = nil, orderedListIndex: Int = 1, alignment: Alignment = .leading) {
        self.manager = .init(content: content, references: references, type: type, alignment: alignment, orderedListIndex: orderedListIndex)
    }
    
    /// Backing player for video blocks initialized when video content appears.
    @State var player: AVPlayer?
    /// Current tab selection for `.tabNavigator` content.
    @State private var tabSelection: ContentSection.Content.Tab = .init(content: [], title: "")
    @Environment(\.colorScheme) var colorScheme
    
    /// Main content body that renders either inline fragments or type-specific block content.
    var body: some View {
        let content = manager.content
        
        VStack {
            if let inlineContent = content.inlineContent {
                InlineContentView(for: inlineContent)
            } else {
                typeBody
            }
        }
        .sheet(item: $manager.enlargedImageSheetIdentifier, content: { identifier in
            EnlargedImageView(identifier: identifier)
        })
        .onAppear {
            if content.type == .video, let identifier = content.identifier, let url = fetchPhotoVideoURL(for: identifier) {
                self.player = AVPlayer(url: url)
            }
            
            if content.type == .tabNavigator, let tab = content.tabs?.first {
                self.tabSelection = tab
            }
        }
        .environment(manager)
    }
    
    /// Produces type-specific UI for the current content node.
    @ViewBuilder
    var typeBody: some View {
        let content = manager.content
        
        switch content.type {
        case .heading:
            if let text = content.text, let level = content.level {
                let font: Font = switch level {
                case 3:
                        .title3
                case 2:
                        .title2
                default:
                        .title
                }
                
                Text(manager.specialStyleString(text))
                    .font(font)
                    .bold()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: self.manager.alignment)
                    .padding(.top, 10)
            }
        case .paragraph:
            if let text = content.text {
                Text(manager.specialStyleString(text))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: self.manager.alignment)
            }
        case .text:
            if let text = content.text {
                Text(manager.specialStyleString(text))
                    .textSelection(.enabled)
            }
        case .strong:
            if let text = content.text {
                Text(manager.specialStyleString(text))
                    .textSelection(.enabled)
                    .bold()
            }
        case .small:
            if let text = content.text {
                Text(manager.specialStyleString(text))
                    .textSelection(.enabled)
                    .font(.caption)
            }
        case .image:
            if let identifier = content.identifier {
                LazyImage(url: fetchPhotoVideoURL(for: identifier)) { state in
                    if state.isLoading {
                        Image(systemSymbol: .photo)
                            .resizable()
                            .scaledToFit()
                    } else if let image = state.image {
                        image
                        .resizable()
                        .scaledToFit()
                    }
                }
                    .frame(maxWidth: 700, maxHeight: 700)
                    .onTapGesture {
                        if let url = fetchPhotoVideoURL(for: identifier) {
                            self.manager.enlargedImageSheetIdentifier = .init(identifier: identifier, url: url)
                        }
                    }
            }
        case .video:
            VideoPlayer(player: player)
                .scaledToFit()
        case .termList:
            if let termListItems = content.termListItems {
                VStack(alignment: manager.alignment.horizontal, spacing: 10) {
                    ForEach(termListItems) { termItem in
                        VStack {
                            InlineContentView(for: termItem.term.inlineContent)
                                .fontWeight(.semibold)
                            
                            ForEach(termItem.definition.content) { content in
                                ArticleContentView(content: content, references: self.manager.references)
                                    .padding(.leading, 15)
                            }
                        }
                    }
                }
            }
        case .unorderedList:
            if let unorderedListItems = content.unorderedListItems {
                ForEach(unorderedListItems) { item in
                    if let content = item.content {
                        VStack(spacing: 5) {
                            ForEach(content) { subcontent in
                                ArticleContentView(content: subcontent, references: self.manager.references, from: .unorderedList)
                                    .padding(.bottom, content.last == subcontent ? 10 : 0)
                            }
                        }
                        
                    }
                }
            }
        case .orderedList:
            if let orderedListItems = content.orderedListItems {
                ForEach(Array(orderedListItems.enumerated()), id: \.element.id) { index, item in
                    if let content = item.content {
                        VStack(spacing: 5) {
                            ForEach(content) { subcontent in
                                ArticleContentView(
                                    content: subcontent,
                                    references: self.manager.references,
                                    from: .orderedList,
                                    orderedListIndex: index + 1
                                )
                                    .padding(.bottom, content.last == subcontent ? 10 : 0)
                            }
                        }
                    }
                }
            }
        case .tabNavigator:
            if let tabs = content.tabs {
                if tabs.count <= 4 {
                    MultilinePicker(data: tabs, selection: self.$tabSelection, cell: { tab in
                        Text(tab.title)
                            .tag(tab.title)
                            .fixedSize(horizontal: false, vertical: true)
                    })
                    .padding([.horizontal, .bottom], 15)
                } else {
                    ScrollView(.horizontal) {
                        MultilinePicker(data: tabs, selection: self.$tabSelection, cell: { tab in
                            Text(tab.title)
                                .tag(tab.title)
                                .fixedSize(horizontal: false, vertical: true)
                        })
                        .padding(.bottom, 15)
                        .padding(.horizontal, 25)
                    }
                    .padding(.horizontal, -25)
                }
                
                ForEach(tabSelection.condensedContent) { tabContents in
                    ArticleContentView(content: tabContents, references: manager.references, alignment: .top)
                }
            }
        case .reference:
            if let identifier = content.identifier, let referenceText = manager.getReferenceText(for: identifier, tintColor: tintColor, deepLinkScheme: deepLinkScheme) {
                Text(referenceText)
            }
        case .table:
            if let rows = content.rows {
                tableView(rows: rows)
            }
        case .emphasis:
            if let inlineContent = content.inlineContent {
                ForEach(inlineContent) { inline in
                    let string = manager.getEmphasisString(inline)
                    
                    Text(string).italic()
                        .textSelection(.enabled)
                }
            }
        case .codeListing:
            GroupBox {
                if let code = content.code {
                    CodeText(code.joined(separator: "\n"))
                        .highlightLanguage(.swift)
                        .codeTextColors(.theme(.xcode))
                        .docCCodeFont()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: .leading, vertical: self.manager.alignment.vertical))
                        .foregroundStyle(Color.primary)
                        .overlay(alignment: .topTrailing) {
                            CodeCopyOverlayButton(string: code.joined(separator: "\n"))
                        }
                }
            }
#if os(visionOS)
            .backgroundStyle(colorScheme == .dark ? .black : .white)
#endif
        case .thematicBreak:
            Divider()
        case .aside:
            if let style = content.style {
                AsideView(style: style, content: content.content ?? [], references: manager.references)
            }
        case .code:
            let attributedString = manager.getCodeString(content.code ?? [])
            
            Text(attributedString)
                .docCCodeFont()
                .textSelection(.enabled)
        case .codeVoice:
            let attributedString = manager.getCodeString(content.code ?? [])
            
            Text(attributedString)
                .docCCodeFont()
                .textSelection(.enabled)
        case .links:
            if let linkItems = content.linkItems, let Style = content.style {
                LinksGridListView(identifiers: linkItems, style: Style, references: manager.references)
            }
        case .row:
            RowContentView(content: content, references: manager.references, alignment: manager.alignment)
        case .none:
            EmptyView()
        }
    }
    
    /// Renders one table row where each cell is represented by a content slice.
    @ViewBuilder
    func tableRow(content: [[ContentSection.Content]]) -> some View {
        HStack {
            ForEach(content, id: \.self) { contentSlice in
                if contentSlice != content.first {
                    Spacer()
                    Divider()
                    Spacer()
                }
                
                VStack {
                    ForEach(contentSlice) { item in
                        ArticleContentView(content: item, references: self.manager.references)
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    /// Renders a full table from parsed row and cell content blocks.
    @ViewBuilder
    func tableView(rows: [[[ContentSection.Content]]]) -> some View {
        VStack(spacing: 0) {
            if let firstRow = rows.first {
                tableRow(content: firstRow)
                    .bold()
            }
            
            ForEach(rows.dropFirst(), id: \.self) { row in
                Divider()
                tableRow(content: row)
            }
        }
    }
    
    /// Convenience wrapper for resolving media URLs with current environment values.
    func fetchPhotoVideoURL(for identifier: String) -> URL? {
        manager.fetchPhotoVideoURL(for: identifier, colorScheme: colorScheme, docCSite: docCSite)
    }
    
    /// Renders adaptive row content and scopes geometry tracking to rows that need it.
    private struct RowContentView: View {
        /// Row content that owns column metadata.
        let content: ContentSection.Content
        /// Reference metadata for nested content.
        let references: [String : Reference]
        /// Alignment used by nested row content.
        let alignment: Alignment
        
        /// Latest measured row width used for adaptive column widths.
        @State private var viewWidth: CGFloat?
        
        var body: some View {
            let columns = content.columns ?? []
            
            Group {
                if !columns.contains(where: { $0.size > 1 }) {
                    let widthDeterminedColumns: Int = if let viewWidth {
                        max(1, Int(viewWidth / 350))
                    } else {
                        columns.count
                    }
                    
                    LazyVGrid(
                        columns: .init(
                            repeating: .init(.flexible(minimum: 50)),
                            count: min(columns.count, widthDeterminedColumns)
                        ),
                        alignment: alignment.horizontal,
                        spacing: 20
                    ) {
                        ForEach(columns, id: \.self) { column in
                            ColumnContentView(column: column, references: references)
                        }
                    }
                } else {
                    HStack {
                        let columnNumber = content.numberOfColumns ?? columns.reduce(0) { partialResult, column in
                            partialResult.advanced(by: column.size)
                        }
                        let columnWidth = if let viewWidth {
                            viewWidth / CGFloat(columnNumber)
                        } else {
                            50.0
                        }
                        
                        ForEach(columns, id: \.self) { column in
                            ColumnContentView(column: column, references: references)
                                .frame(
                                    maxWidth: columnWidth * CGFloat(column.size),
                                    maxHeight: .infinity,
                                    alignment: .top
                                )
                        }
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width.rounded(.toNearestOrAwayFromZero)
            } action: { newValue in
                guard viewWidth != newValue else { return }
                
                viewWidth = newValue
            }
        }
    }
    
    /// Renders all content blocks inside a row column.
    private struct ColumnContentView: View {
        /// Column metadata and child content.
        let column: ContentSection.Content.Column
        /// Reference metadata for nested content.
        let references: [String : Reference]
        
        var body: some View {
            VStack(alignment: .center) {
                ForEach(column.content) { content in
                    ArticleContentView(content: content, references: references)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
    
    // swiftlint:disable shorthand_operator cyclomatic_complexity
    /// Renders inline content fragments (text, emphasis, code, media, and references) into composed views.
    struct InlineContentView: View {
        /// Inline content fragments to render.
        let content: [ContentStruct]
        /// Optional alignment override for emitted text blocks.
        let alignment: Alignment?
        
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.docCSite) private var docCSite
        @Environment(\.docCTintColor) var tintColor
        @Environment(\.docCDeepLinkScheme) private var deepLinkScheme
        
        @Environment(ArticleContentManager.self) private var manager
        
        /// Creates an inline content renderer for a sequence of inline nodes.
        init(for content: [ContentStruct], alignment: Alignment? = nil) {
            self.content = content
            self.alignment = alignment
        }
        
        /// Resolves media URLs for inline image/video nodes.
        func fetchPhotoVideoURL(for identifier: String) -> URL? {
            manager.fetchPhotoVideoURL(for: identifier, colorScheme: colorScheme, docCSite: docCSite)
        }
        
        /// Inline body that folds all fragments into rendered text/media segments.
        var body: some View {
            let views = manager.inlineContentSegments(for: content, tintColor: tintColor, deepLinkScheme: deepLinkScheme, docCSource: docCSite)
            
            return VStack {
                ForEach(views) { inlineContent in
                    segmentView(inlineContent)
                }
            }
            .padding(.bottom, [ContentType.unorderedList, .orderedList].contains(manager.type) ? 5 : 0)
        }
        
        /// Renders one inline segment without type-erasing every fragment during body construction.
        @ViewBuilder
        private func segmentView(_ segment: ArticleInlineContent) -> some View {
            switch segment.kind {
            case .text(let text):
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: alignment ?? manager.alignment)
            case .image(let identifier, let abstract):
                LazyImage(url: fetchPhotoVideoURL(for: identifier)) { state in
                    if state.isLoading {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.clear)
                            .stroke(Color.primary, lineWidth: 2)
                            .scaledToFit()
                            .overlay {
                                ProgressView()
                            }
                    } else if let image = state.image {
                        image
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxWidth: 700, maxHeight: 700, alignment: manager.alignment)
                .padding(.bottom)
                .onTapGesture {
                    if let url = fetchPhotoVideoURL(for: identifier) {
                        manager.enlargedImageSheetIdentifier = .init(identifier: identifier, url: url)
                    }
                }
                
                ForEach(abstract) { ref in
                    InlineContentView(for: [ref], alignment: .top)
                        .multilineTextAlignment(.center)
                }
            case .video(let identifier):
                if let url = fetchPhotoVideoURL(for: identifier) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .scaledToFit()
                }
            }
        }
    }
    // swiftlint:enable shorthand_operator cyclomatic_complexity
}

// swiftlint:enable type_body_length
