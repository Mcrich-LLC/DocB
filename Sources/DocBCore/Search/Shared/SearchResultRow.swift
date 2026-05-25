import SwiftUI
import DocCKit

/// Shared Search Documentation result row icon, subtitle, and accessibility behavior.
struct SearchResultRow: View {
    let row: SidebarSearchResultRow
    let isSelected: Bool
    let metrics: SearchResultRowMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.spacing) {
                icon
                    .font(metrics.iconFont)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: metrics.iconSize, height: metrics.iconSize)

                VStack(alignment: .leading, spacing: metrics.textSpacing) {
                    Text(row.title)
                        .font(metrics.titleFont)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(metrics.subtitleFont)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: metrics.spacing)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(height: metrics.height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this documentation result.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var icon: Image {
        switch row {
        case .homepage:
            Image(systemName: "house")
        case .reference(let result):
            switch Role(rawValue: result.type) {
            case .symbol, .pseudoSymbol, .restRequestSymbol:
                Image(systemName: "curlybraces")
            case .collection, .collectionGroup:
                Image(systemName: "square.stack")
            default:
                Image(systemName: "doc.text")
            }
        case .technology:
            Image(systemName: "shippingbox")
        }
    }

    private var subtitle: String {
        switch row {
        case .homepage:
            "DocB"
        case .reference(let result):
            result.type.capitalized
        case .technology(let result):
            result.framework.docCSite?.overrideName ?? "Technology"
        }
    }

    private var accessibilityLabel: String {
        "\(row.title), \(subtitle)"
    }
}

/// Platform-specific visual metrics for a search result row.
struct SearchResultRowMetrics {
    let height: CGFloat
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let textSpacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconSize: CGFloat
    let iconFont: Font
    let titleFont: Font
    let subtitleFont: Font
}

extension SidebarSearchResults {
    var flattenedRows: [SidebarSearchResultRow] {
        sections.flatMap(\.rows)
    }
}
