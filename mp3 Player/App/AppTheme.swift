import SwiftUI

enum AppTheme {
    static let tint = Color(red: 0.18, green: 0.32, blue: 0.28)
}

private struct AppScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private struct AppListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
    }
}

extension View {
    func appScreen() -> some View {
        modifier(AppScreenStyle())
    }

    func appList() -> some View {
        modifier(AppListStyle())
    }
}
