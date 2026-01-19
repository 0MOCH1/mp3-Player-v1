//
//  TrackRowView 2.swift
//  mp3 Player
//
//  Created by Minato on 2026/01/23.
//
import SwiftUI

struct GeneralRowView: View {
    let title: String
    let cornerRadius: CGFloat = 6
    var placeholderSystemImage: String = "plus"
    private let artworkSize: CGFloat = 48
    private let numberColumnWidth: CGFloat = 24
    private let rowVPad: CGFloat = 4
    private let hGap: CGFloat = 0
    
    
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    
    private var onePixel: CGFloat {
        1 / displayScale
    }
    
    var body: some View {
            HStack(spacing: hGap) {
                FavoriteIndicatorView(isFavorite: false)
                
                ZStack {
                    Rectangle()
                        .fill(.secondary.opacity(0.15))
                    
                    Image(systemName: placeholderSystemImage)
                        .foregroundStyle(.tint)
                        .font(.title2.weight(.semibold))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.separator.opacity(0.5), lineWidth: onePixel)
                        .allowsHitTesting(false)
                }
                .frame(width: artworkSize, height: artworkSize)
                .clipped()
                .padding(.trailing, 12)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, rowVPad)
            .contentShape(Rectangle())
        }
            
    }
    
