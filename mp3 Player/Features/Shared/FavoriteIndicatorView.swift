import SwiftUI

struct FavoriteIndicatorView: View {
    let isFavorite: Bool
    var size: CGFloat = 8

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size))
            .foregroundStyle(.red)
            .opacity(isFavorite ? 1 : 0)
            .frame(width: size+12, height: size, alignment: .center)
    }
}
