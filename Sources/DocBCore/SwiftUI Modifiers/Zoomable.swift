import SwiftUI

/// Adds pinch, drag, and double-tap zoom behavior to any SwiftUI view.
///
/// - Warning: This modifier assumes content is anchored at `.zero` and clamps translation to content bounds.
struct ZoomableModifier: ViewModifier {
    let minZoomScale: CGFloat
    let doubleTapZoomScale: CGFloat

    @State private var lastTransform: CGAffineTransform = .identity
    @State private var transform: CGAffineTransform = .identity
    @State private var contentSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self, of: { proxy in
                CGSize(
                    width: proxy.size.width.rounded(.toNearestOrAwayFromZero),
                    height: proxy.size.height.rounded(.toNearestOrAwayFromZero)
                )
            }, action: { newValue in
                guard contentSize != newValue else { return }
                
                contentSize = newValue
            })
            .animatableTransformEffect(transform)
            .gesture(dragGesture, including: transform == .identity ? .none : .all)
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.gesture(magnificationGesture)
                } else {
                    view.gesture(oldMagnificationGesture)
                }
            }
            .gesture(doubleTapGesture)
    }

    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private var oldMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let zoomFactor = 0.5
                let scale = value * zoomFactor
                transform = lastTransform.scaledBy(x: scale, y: scale)
            }
            .onEnded { _ in
                onEndGesture()
            }
    }

    @available(iOS 17.0, *)
    private var magnificationGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                let newTransform = CGAffineTransform.anchoredScale(
                    scale: value.magnification,
                    anchor: value.startAnchor.scaledBy(contentSize)
                )

                withAnimation(.interactiveSpring) {
                    transform = lastTransform.concatenating(newTransform)
                }
            }
            .onEnded { _ in
                onEndGesture()
            }
    }

    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                let newTransform: CGAffineTransform =
                    if transform.isIdentity {
                        .anchoredScale(scale: doubleTapZoomScale, anchor: value.location)
                    } else {
                        .identity
                    }

                withAnimation(.linear(duration: 0.15)) {
                    transform = newTransform
                    lastTransform = newTransform
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(.interactiveSpring) {
                    transform = lastTransform.translatedBy(
                        x: value.translation.width / transform.scaleX,
                        y: value.translation.height / transform.scaleY
                    )
                }
            }
            .onEnded { _ in
                onEndGesture()
            }
    }

    private func onEndGesture() {
        let newTransform = limitTransform(transform)

        withAnimation(.snappy(duration: 0.1)) {
            transform = newTransform
            lastTransform = newTransform
        }
    }

    private func limitTransform(_ transform: CGAffineTransform) -> CGAffineTransform {
        let scaleX = transform.scaleX
        let scaleY = transform.scaleY

        if scaleX < minZoomScale || scaleY < minZoomScale {
            return .identity
        }

        let maxX = contentSize.width * (scaleX - 1)
        let maxY = contentSize.height * (scaleY - 1)

        if transform.tx > 0
            || transform.tx < -maxX
            || transform.ty > 0
            || transform.ty < -maxY {
            let tx = min(max(transform.tx, -maxX), 0)
            let ty = min(max(transform.ty, -maxY), 0)
            var transform = transform
            transform.tx = tx
            transform.ty = ty
            return transform
        }

        return transform
    }
}

/// Public zooming APIs that attach `ZoomableModifier` behavior to views.
public extension View {
    /// Enables interactive zoom and pan gestures on the receiving view.
    ///
    /// - Parameters:
    ///   - minZoomScale: Minimum allowed zoom before the transform resets to identity.
    ///   - doubleTapZoomScale: Zoom level toggled by a double tap.
    @ViewBuilder
    func zoomable(
        minZoomScale: CGFloat = 1,
        doubleTapZoomScale: CGFloat = 3
    ) -> some View {
        modifier(ZoomableModifier(
            minZoomScale: minZoomScale,
            doubleTapZoomScale: doubleTapZoomScale
        ))
    }

    /// Enables interactive zoom while filling out-of-bounds space with a background color.
    ///
    /// - Parameters:
    ///   - minZoomScale: Minimum allowed zoom before the transform resets to identity.
    ///   - doubleTapZoomScale: Zoom level toggled by a double tap.
    ///   - outOfBoundsColor: Background color shown when transformed content exposes empty space.
    @ViewBuilder
    func zoomable(
        minZoomScale: CGFloat = 1,
        doubleTapZoomScale: CGFloat = 3,
        outOfBoundsColor: Color = .clear
    ) -> some View {
        ZStack {
            outOfBoundsColor
            self.zoomable(
                minZoomScale: minZoomScale,
                doubleTapZoomScale: doubleTapZoomScale
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Internal helper APIs used to compose conditional and transform-based view behavior.
private extension View {
    @ViewBuilder
    func modify(@ViewBuilder _ fn: (Self) -> some View) -> some View {
        fn(self)
    }

    @ViewBuilder
    func animatableTransformEffect(_ transform: CGAffineTransform) -> some View {
        scaleEffect(
            x: transform.scaleX,
            y: transform.scaleY,
            anchor: .zero
        )
        .offset(x: transform.tx, y: transform.ty)
    }
}

/// Geometry helpers for mapping normalized anchors into concrete coordinates.
private extension UnitPoint {
    func scaledBy(_ size: CGSize) -> CGPoint {
        .init(
            x: x * size.width,
            y: y * size.height
        )
    }
}

/// Transform helpers for anchored scaling and extracting effective scale factors.
private extension CGAffineTransform {
    static func anchoredScale(scale: CGFloat, anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: anchor.x, y: anchor.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -anchor.x, y: -anchor.y)
    }

    var scaleX: CGFloat {
        sqrt(a * a + c * c)
    }

    var scaleY: CGFloat {
        sqrt(b * b + d * d)
    }
}
