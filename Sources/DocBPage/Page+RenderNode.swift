// Building a Page from DocC's render JSON: the one place that knows the shape of a render
// node, resolves references to titles and targets, and decides what goes where. The node is
// expected to have its language variant already applied; the host picks the language.

import DocCSchema
import Foundation

extension Page {
    public init(node: RenderNode) {
        let builder = Builder(references: node.references)
        let platforms = (node.metadata.platforms ?? []).compactMap { item -> Platform? in
            guard let name = item.name else { return nil }
            return Platform(name: name, introduced: item.introduced, deprecated: item.deprecated ?? (item.unconditionallyDeprecated == true ? "" : nil), isBeta: item.isBeta ?? false)
        }
        self.init(
            title: node.metadata.title ?? "Untitled",
            roleHeading: node.metadata.roleHeading,
            role: node.metadata.role,
            symbolKind: node.metadata.symbolKind,
            standardColor: node.metadata.color?.standardColorIdentifier,
            language: node.identifier.sourceLanguage.id,
            abstract: builder.runs(node.abstract ?? []),
            isBeta: !platforms.isEmpty && platforms.allSatisfy(\.isBeta),
            // As the web renderer decides it: the page's own reference says so, there is a
            // deprecation summary, or every platform has deprecated it.
            isDeprecated: (node.references[node.identifier.absoluteString] as? TopicRenderReference)?.isDeprecated == true
                || node.deprecationSummary != nil || (!platforms.isEmpty && platforms.allSatisfy { $0.deprecated != nil }),
            platforms: platforms
        )

        if case .reference(let hierarchy)? = node.hierarchyVariants.defaultValue, let path = hierarchy.paths.first {
            parents = path.compactMap { identifier in
                (node.references[identifier] as? TopicRenderReference).map { Links.Item(title: $0.title, link: $0.url) }
            }
        }
        if let action = node.sampleDownload?.action, case .reference(let identifier, _, let overridingTitle, _) = action,
           let reference = node.references[identifier.identifier] as? DownloadReference {
            download = Download(title: overridingTitle ?? "Download", url: reference.url.absoluteString)
        }
        if let summary = node.deprecationSummary {
            body.append(.aside(Aside(kind: .deprecated, blocks: builder.blocks(summary))))
        }
        for section in node.primaryContentSections {
            switch section {
            case let section as DeclarationsRenderSection:
                for declaration in section.declarations {
                    body.append(.declaration(builder.tokens(declaration.tokens)))
                }
            case let section as ContentRenderSection:
                body += builder.blocks(section.content)
            case let section as ParametersRenderSection:
                body.append(.heading(level: 2, text: "Parameters", anchor: "parameters"))
                body.append(.terms(section.parameters.map { Term(term: [Run($0.name, .code)], definition: builder.blocks($0.content)) }))
            case let section as MentionsRenderSection where !section.mentions.isEmpty:
                body.append(.heading(level: 2, text: "Mentioned In", anchor: "mentions"))
                body.append(.links(Links(style: .list, items: builder.linkItems(section.mentions.map(\.absoluteString)))))
            case let section as PossibleValuesRenderSection:
                body.append(.heading(level: 2, text: section.title ?? "Possible Values", anchor: "possible-values"))
                body.append(.terms(section.values.map { Term(term: [Run($0.name, .code)], definition: builder.blocks($0.content ?? [])) }))
            // REST pages, as the web shows them: the endpoint as a declaration, then parameters,
            // body, responses and an object's properties as term lists of name, type and text.
            case let section as RESTEndpointRenderSection:
                body.append(.heading(level: 2, text: section.title, anchor: "url"))
                body.append(.declaration(section.tokens.map { token in
                    let kind = switch token.kind {
                    case .method: "keyword"
                    case .baseURL: "label"
                    default: "text"
                    }
                    return Token(token.text, kind: kind)
                }))
            case let section as RESTParametersRenderSection where !section.parameters.isEmpty:
                body.append(.heading(level: 2, text: section.title, anchor: section.source.rawValue + "-parameters"))
                body.append(.terms(section.parameters.map(builder.term(for:))))
            case let section as RESTBodyRenderSection:
                body.append(.heading(level: 2, text: section.title, anchor: "http-body"))
                if !section.bodyContentType.isEmpty { body.append(.declaration(builder.tokens(section.bodyContentType))) }
                body.append(.small([Run("Content-Type: " + section.mimeType)]))
                body += builder.blocks(section.content ?? [])
                if let parameters = section.parameters, !parameters.isEmpty { body.append(.terms(parameters.map(builder.term(for:)))) }
            case let section as RESTResponseRenderSection where !section.responses.isEmpty:
                body.append(.heading(level: 2, text: section.title, anchor: "response-codes"))
                body.append(.terms(section.responses.map { response in
                    var definition: [Block] = []
                    if !response.type.isEmpty { definition.append(.paragraph(builder.codeRuns(response.type))) }
                    definition += builder.blocks(response.content ?? []).filter { !$0.isBlank }
                    if let mime = response.mimeType { definition.append(.small([Run("Content-Type: " + mime)])) }
                    return Term(term: [Run(String(response.status), .code)] + (response.reason.map { [Run(" " + $0)] } ?? []), definition: definition)
                }))
            case let section as PropertiesRenderSection where !section.items.isEmpty:
                body.append(.heading(level: 2, text: section.title, anchor: "properties"))
                body.append(.terms(section.items.map(builder.term(for:))))
            case let section as AttributesRenderSection:
                let attributes = builder.attributeBlocks(section.attributes ?? [])
                if !attributes.isEmpty {
                    body.append(.heading(level: 2, text: section.title, anchor: "attributes"))
                    body += attributes
                }
            default:
                body.append(.unsupported(section.kind.rawValue))
            }
        }
        // Pages without primary content, such as tutorials, carry their content in `sections`.
        if node.primaryContentSections.isEmpty {
            body += node.sections.map { .unsupported($0.kind.rawValue) }
        }

        let style: Links.Style? = switch node.topicSectionsStyle {
        case .list, .unknown: .list
        case .compactGrid: .compactGrid
        case .detailedGrid: .detailedGrid
        case .hidden: nil
        }
        if let style {
            appendLinkSections("Topics", anchor: "topics", groups: node.topicSections, style: style, builder: builder)
        }
        appendLinkSections("Default Implementations", anchor: "default-implementations", groups: node.defaultImplementationsSections, style: .list, builder: builder)
        if !node.relationshipSections.isEmpty {
            body.append(.heading(level: 2, text: "Relationships", anchor: "relationships"))
            for section in node.relationshipSections {
                body.append(.heading(level: 3, text: section.title))
                body.append(.links(Links(style: .list, items: builder.linkItems(section.identifiers))))
            }
        }
        appendLinkSections("See Also", anchor: "see-also", groups: node.seeAlsoSections, style: .list, builder: builder)
    }

    private mutating func appendLinkSections(_ title: String, anchor: String, groups: [TaskGroupRenderSection], style: Links.Style, builder: Builder) {
        let groups = groups.filter { !$0.identifiers.isEmpty }
        guard !groups.isEmpty else { return }
        body.append(.heading(level: 2, text: title, anchor: anchor))
        for group in groups {
            if let title = group.title {
                body.append(.heading(level: 3, text: title, anchor: group.anchor))
            }
            if let abstract = group.abstract, !abstract.isEmpty {
                body.append(.paragraph(builder.runs(abstract)))
            }
            if let discussion = group.discussion as? ContentRenderSection {
                body += builder.blocks(discussion.content)
            }
            body.append(.links(Links(style: style, items: builder.linkItems(group.identifiers))))
        }
    }
}

/// Walks render content with the page's references at hand.
struct Builder {
    let references: [String: any RenderReference]

    // MARK: Inline

    /// Nested inline markup flattened into runs; adjacent runs that look alike are merged.
    func runs(_ content: [RenderInlineContent], style: Run.Style = [], link: String? = nil) -> [Run] {
        var out: [Run] = []
        func append(_ run: Run) {
            if run.text.isEmpty { return }
            if var last = out.last, last.style == run.style, last.link == run.link {
                last.text += run.text
                out[out.count - 1] = last
            } else {
                out.append(run)
            }
        }
        for element in content {
            switch element {
            case .text(let text):
                append(Run(text, style, link: link))
            case .codeVoice(let code):
                append(Run(code, style.union(.code), link: link))
            case .emphasis(let inner):
                runs(inner, style: style.union(.emphasis), link: link).forEach(append)
            case .strong(let inner):
                runs(inner, style: style.union(.strong), link: link).forEach(append)
            case .strikethrough(let inner):
                runs(inner, style: style.union(.strikethrough), link: link).forEach(append)
            case .subscript(let inner):
                runs(inner, style: style.union(.subscript), link: link).forEach(append)
            case .superscript(let inner):
                runs(inner, style: style.union(.superscript), link: link).forEach(append)
            case .newTerm(let inner):
                runs(inner, style: style.union(.emphasis), link: link).forEach(append)
            case .inlineHead(let inner):
                runs(inner, style: style.union(.strong), link: link).forEach(append)
            case .reference(let identifier, let isActive, let overridingTitle, let overridingInline):
                let target = isActive ? self.target(for: identifier.identifier) : nil
                if let overridingInline {
                    runs(overridingInline, style: style, link: target ?? link).forEach(append)
                } else {
                    let title = overridingTitle ?? self.title(for: identifier.identifier)
                    // Symbol references read as code, the way DocC shows them.
                    let isSymbol = (references[identifier.identifier] as? TopicRenderReference)?.kind == .symbol
                    append(Run(title, isSymbol ? style.union(.code) : style, link: target ?? link))
                }
            case .image(let identifier, let metadata):
                // Images inside a paragraph become blocks of their own (see `blocks`); elsewhere
                // only their text survives.
                let alt = (references[identifier.identifier] as? ImageReference)?.altText ?? metadata?.abstract?.plainText
                if let alt, !alt.isEmpty { append(Run(alt, style, link: link)) }
            case .unknown:
                break
            }
        }
        return out
    }

    func title(for identifier: String) -> String {
        switch references[identifier] {
        case let topic as TopicRenderReference: topic.title
        case let link as LinkReference: link.title
        case let unresolved as UnresolvedRenderReference: unresolved.title
        default: identifier.split(separator: "/").last.map(String.init) ?? identifier
        }
    }

    /// Where a reference leads: the page path for topics, the URL for links, nothing for the unresolvable.
    func target(for identifier: String) -> String? {
        switch references[identifier] {
        case let topic as TopicRenderReference: topic.url
        case let link as LinkReference: link.url
        case is UnresolvedRenderReference: nil
        case nil: identifier
        default: identifier
        }
    }

    func tokens(_ tokens: [DeclarationRenderSection.Token]) -> [Token] {
        tokens.map { Token($0.text, kind: $0.kind.rawValue, link: $0.identifier.flatMap(target(for:))) }
    }

    /// Declaration tokens as code runs in a paragraph, linked where they are.
    func codeRuns(_ tokens: [DeclarationRenderSection.Token]) -> [Run] {
        tokens.map { Run($0.text, .code, link: $0.identifier.flatMap(target(for:))) }
    }

    // MARK: REST

    /// A parameter or property as a term: its name, then its type with what the web says beside
    /// it (required, deprecated, read-only), its text, and its attributes.
    func term(for property: RenderProperty) -> Term {
        var type = codeRuns(property.type)
        var notes: [String] = []
        if property.required == true { notes.append("Required") }
        if property.deprecated == true { notes.append("Deprecated") }
        if property.readOnly == true { notes.append("Read only") }
        if !notes.isEmpty { type.append(Run(" (" + notes.joined(separator: ", ") + ")")) }
        var definition: [Block] = type.isEmpty ? [] : [.paragraph(type)]
        definition += blocks(property.content ?? []).filter { !$0.isBlank }
        definition += attributeBlocks(property.attributes ?? [])
        return Term(term: [Run(property.name, .code)], definition: definition)
    }

    /// Attributes as the web's lines: "Default: x", "Possible Values: a, b".
    func attributeBlocks(_ attributes: [RenderAttribute]) -> [Block] {
        attributes.compactMap { attribute -> Block? in
            let (label, values): (String, [Run]) = switch attribute {
            case .default(let value): ("Default", [Run(value, .code)])
            case .minimum(let value): ("Minimum", [Run(value, .code)])
            case .minimumExclusive(let value): ("Minimum", [Run("> " + value, .code)])
            case .maximum(let value): ("Maximum", [Run(value, .code)])
            case .maximumExclusive(let value): ("Maximum", [Run("< " + value, .code)])
            case .minimumLength(let value): ("Minimum length", [Run(value, .code)])
            case .maximumLength(let value): ("Maximum length", [Run(value, .code)])
            case .allowedValues(let values): ("Possible Values", Array(values.map { [Run($0, .code)] }.joined(separator: [Run(", ")])))
            case .allowedTypes(let types): ("Possible types", Array(types.map(codeRuns).joined(separator: [Run(", ")])))
            case .unknown: ("", [])
            }
            guard !label.isEmpty else { return nil }
            return .paragraph([Run(label + ":", .strong), Run(" ")] + values)
        }
    }

    func media(for identifier: String, caption: [RenderInlineContent]? = nil) -> Media? {
        let asset: DataAsset
        let alt: String?
        switch references[identifier] {
        case let image as ImageReference: asset = image.asset; alt = image.altText
        case let video as VideoReference: asset = video.asset; alt = video.altText
        default: return nil
        }
        let variants = asset.variants
            .map { traits, url in Media.Variant(url: url.relativeString, isDark: traits.userInterfaceStyle == .dark, scale: traits.displayScale.map { Int($0.scaleFactor) } ?? 1) }
            .sorted { ($0.isDark ? 1 : 0, $0.scale, $0.url) < ($1.isDark ? 1 : 0, $1.scale, $1.url) }
        return Media(variants: variants, alt: alt, caption: runs(caption ?? []))
    }

    func linkItems(_ identifiers: [String]) -> [Links.Item] {
        identifiers.compactMap { identifier in
            switch references[identifier] {
            case let topic as TopicRenderReference:
                Links.Item(title: topic.title, fragments: tokens(topic.fragments ?? []), link: topic.url, abstract: runs(topic.abstract), isBeta: topic.isBeta, isDeprecated: topic.isDeprecated, role: topic.role,
                           image: topic.images.first { $0.type == .card }.flatMap { media(for: $0.identifier.identifier) })
            case let link as LinkReference:
                Links.Item(title: link.title, link: link.url)
            case let unresolved as UnresolvedRenderReference:
                Links.Item(title: unresolved.title, link: nil)
            default:
                nil
            }
        }
    }

    // MARK: Blocks

    func blocks(_ content: [RenderBlockContent]) -> [Block] {
        var out: [Block] = []
        for block in content {
            switch block {
            case .paragraph(let paragraph):
                out += paragraphBlocks(paragraph.inlineContent)
            case .heading(let heading):
                out.append(.heading(level: heading.level, text: heading.text, anchor: heading.anchor))
            case .codeListing(let listing):
                out.append(.code(Code(lines: listing.code, language: listing.syntax ?? listing.options?.language)))
            case .orderedList(let list):
                out.append(.list(List(isOrdered: true, start: Int(list.startIndex), items: list.items.map { blocks($0.content) })))
            case .unorderedList(let list):
                out.append(.list(List(isOrdered: false, items: list.items.map { blocks($0.content) })))
            case .termList(let list):
                out.append(.terms(list.items.map { Term(term: runs($0.term.inlineContent), definition: blocks($0.definition.content)) }))
            case .aside(let aside):
                let kind = Aside.Kind(rawValue: aside.style.rawValue) ?? .note
                out.append(.aside(Aside(kind: kind, name: aside.name.isEmpty ? nil : aside.name, blocks: blocks(aside.content))))
            case .table(let table):
                out.append(.table(self.table(table)))
            case .row(let row):
                out.append(.row(Row(columns: row.columns.map { Row.Column(size: max(1, $0.size), blocks: blocks($0.content)) })))
            case .small(let small):
                out.append(.small(runs(small.inlineContent)))
            case .tabNavigator(let navigator):
                out.append(.tabs(navigator.tabs.map { Tab(title: $0.title, blocks: blocks($0.content)) }))
            case .links(let links):
                let style: Links.Style = switch links.style {
                case .compactGrid: .compactGrid
                case .detailedGrid: .detailedGrid
                default: .list
                }
                out.append(.links(Links(style: style, items: linkItems(links.items))))
            case .video(let video):
                let poster = (references[video.identifier.identifier] as? VideoReference)?.poster.flatMap { media(for: $0.identifier) }
                out.append(media(for: video.identifier.identifier, caption: video.metadata?.abstract).map { Block.video($0, poster: poster) } ?? .unsupported("video"))
            case .thematicBreak:
                out.append(.divider)
            case .step:
                out.append(.unsupported("step"))
            case .endpointExample:
                out.append(.unsupported("endpointExample"))
            case .dictionaryExample:
                out.append(.unsupported("dictionaryExample"))
            case .unknown(let json):
                out.append(.unsupported(json.blockType ?? "unknown"))
            }
        }
        return out
    }

    /// A paragraph, split around the images in it: DocC puts a figure in a paragraph of its own.
    private func paragraphBlocks(_ content: [RenderInlineContent]) -> [Block] {
        var out: [Block] = []
        var pending: [RenderInlineContent] = []
        func flush() {
            let runs = runs(pending)
            if !runs.isEmpty { out.append(.paragraph(runs)) }
            pending = []
        }
        for element in content {
            if case .image(let identifier, let metadata) = element, let media = media(for: identifier.identifier, caption: metadata?.abstract) {
                flush()
                out.append(.image(media))
            } else {
                pending.append(element)
            }
        }
        flush()
        return out
    }

    private func table(_ table: RenderBlockContent.Table) -> Table {
        let spans = Dictionary(table.extendedData.map { (($0.rowIndex, $0.columnIndex), $0) }, uniquingKeysWith: { first, _ in first })
        let header: Table.Header = switch table.header {
        case .row: .row
        case .column: .column
        case .both: .both
        default: .none
        }
        let alignments: [Table.Alignment] = (table.alignments ?? []).map {
            switch $0 {
            case .left: .left
            case .center: .center
            case .right: .right
            default: .unset
            }
        }
        // DocC keeps a cell under every spanned-over position too, with spans of zero; the
        // model keeps only real cells, the way HTML does.
        let rows = table.rows.enumerated().map { rowIndex, row in
            row.cells.enumerated().compactMap { columnIndex, cell -> Table.Cell? in
                let span = spans[rowIndex, columnIndex]
                let columnSpan = span.map { Int($0.colspan) } ?? 1
                let rowSpan = span.map { Int($0.rowspan) } ?? 1
                guard columnSpan > 0, rowSpan > 0 else { return nil }
                return Table.Cell(blocks(cell), columnSpan: columnSpan, rowSpan: rowSpan)
            }
        }
        return Table(header: header, alignments: alignments, rows: rows)
    }
}

private struct Position: Hashable {
    let row: Int
    let column: Int
}

private extension Dictionary where Key == Position {
    subscript(row: Int, column: Int) -> Value? { self[Position(row: row, column: column)] }
}

private extension Dictionary where Key == Position, Value == RenderBlockContent.TableCellExtendedData {
    init(_ pairs: [((Int, Int), Value)], uniquingKeysWith: (Value, Value) -> Value) {
        self.init(pairs.map { (Position(row: $0.0.0, column: $0.0.1), $0.1) }, uniquingKeysWith: uniquingKeysWith)
    }
}

private extension JSON {
    /// The `type` of an unknown block, when it is an object with one.
    var blockType: String? {
        if case .dictionary(let fields) = self, case .string(let type)? = fields["type"] { return type }
        return nil
    }
}
