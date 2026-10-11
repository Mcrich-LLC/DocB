import SwiftUI

/// The blocks' views laid over the page, each at its frame; the page's size, so nothing
/// else decides it.
struct BlockLayer: View {
    let placements: BlockPlacements

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(placements.items) { item in
                item.view
                    .frame(width: item.frame.width, height: item.frame.height, alignment: .topLeading)
                    .offset(x: item.frame.minX, y: item.frame.minY)
            }
        }
        .frame(width: placements.size.width, height: placements.size.height, alignment: .topLeading)
    }
}
