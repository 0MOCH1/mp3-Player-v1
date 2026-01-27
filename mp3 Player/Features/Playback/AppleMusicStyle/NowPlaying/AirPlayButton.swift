//
//  AirPlayButton.swift
//  mp3 Player
//
//  Created by GitHub Copilot on 25.01.2026.
//

import SwiftUI
import AVKit

struct AirPlayButton: View {
    // サイズを指定可能にして他のボタンと合わせる
    var size: CGFloat = 28
    var fontWeight: Font.Weight = .semibold
    
    var body: some View {
        AirPlayButtonRepresentable()
            .frame(width: size, height: size)
            .blendMode(.overlay)
    }
}

private struct AirPlayButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        // 他のボタンと同じ色（palette.opaque相当）を使用
        routePickerView.tintColor = UIColor.palette.playerCard.opaque
        routePickerView.activeTintColor = UIColor.palette.playerCard.opaque
        routePickerView.prioritizesVideoDevices = false
        
        // ボタンのサイズを調整
        for subview in routePickerView.subviews {
            if let button = subview as? UIButton {
                button.contentMode = .scaleAspectFit
                // フォントサイズを設定
                button.setPreferredSymbolConfiguration(
                    UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold),
                    forImageIn: .normal
                )
            }
        }
        
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // tintColor更新
        uiView.tintColor = UIColor.palette.playerCard.opaque
    }
}
