import SwiftUI

struct AppCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 4)
    }
}

struct AppSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
    }
}

struct AppInlineInfo: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}
