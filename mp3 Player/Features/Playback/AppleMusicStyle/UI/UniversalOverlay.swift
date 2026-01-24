//
//  UniversalOverlay.swift
//  mp3 Player
//

import SwiftUI

extension View {
    @ViewBuilder
    func universalOverlay<Content: View>(
        animation: Animation? = .snappy,
        show: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            UniversalOverlayModifier(
                animation: animation,
                show: show,
                viewContent: content
            )
        )
    }
}

struct OverlayableRootView<Content: View>: View {
    var content: Content
    fileprivate var properties = UniversalOverlayProperties()

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(properties)
            .onAppear {
                let windowScene = (UIApplication.shared.connectedScenes.first as? UIWindowScene)
                if let windowScene, properties.window == nil {
                    let window = PassthroughWindow(windowScene: windowScene)
                    window.isHidden = false
                    window.isUserInteractionEnabled = true
                    let rootViewController = UIHostingController(
                        rootView: UniversalOverlayViews().environment(properties)
                    )
                    rootViewController.view.backgroundColor = .clear
                    window.rootViewController = rootViewController
                    properties.window = window
                }
            }
    }
}

@Observable
private class UniversalOverlayProperties {
    var window: UIWindow?
    var views: [OverlayView] = []

    struct OverlayView: Identifiable {
        var id: String = UUID().uuidString
        var view: AnyView
    }
}

private struct UniversalOverlayModifier<ViewContent: View>: ViewModifier {
    var animation: Animation?
    @Binding var show: Bool
    @ViewBuilder var viewContent: ViewContent
    @Environment(UniversalOverlayProperties.self) private var properties
    @State private var viewID: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: show, initial: true) { _, newValue in
                if newValue {
                    addView()
                } else {
                    removeView()
                }
            }
    }

    private func addView() {
        if properties.window != nil && viewID == nil {
            viewID = UUID().uuidString
            guard let viewID else { return }

            withAnimation(animation) {
                properties.views.append(
                    .init(id: viewID, view: .init(viewContent))
                )
            }
        }
    }

    private func removeView() {
        if let viewID {
            withAnimation(animation) {
                properties.views.removeAll(where: { $0.id == viewID })
            }

            self.viewID = nil
        }
    }
}

private struct UniversalOverlayViews: View {
    @Environment(UniversalOverlayProperties.self) private var properties
    var body: some View {
        ZStack {
            ForEach(properties.views) { $0.view }
        }
    }
}

private class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event), let rootView = rootViewController?.view else {
            return nil
        }

        if #available(iOS 18, *) {
            for subview in rootView.subviews.reversed() {
                let pointInSubView = subview.convert(point, from: rootView)
                if subview.hitTest(pointInSubView, with: event) != nil {
                    return hitView
                }
            }
            return nil
        } else {
            return hitView == rootView ? nil : hitView
        }
    }
}
