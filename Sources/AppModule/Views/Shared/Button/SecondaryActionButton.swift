//
//  SecondaryActionButton.swift
//  DarumaColorApp
//
//  Created by 伊藤璃乃 on 2026/01/07.
//

import SwiftUI

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: {
            SoundPlayer.shared.playSelect()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.shiranui(size: 18))
                Text(title)
                    .font(.shiranui(size: 18))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Image.woodBackground
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 1.5)
            )
            .clipped()
            .overlay(
                Rectangle()
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}
