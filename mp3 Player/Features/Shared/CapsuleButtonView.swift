//
//  CapsuleButtonView.swift
//  mp3 Player
//
//  Created by Minato on 2026/01/23.
//

import SwiftUI

struct CapsuleButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }
    
}
