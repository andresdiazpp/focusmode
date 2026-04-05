//
//  ModePickerView.swift
//  FocusMode
//

import SwiftUI

// ModePickerView muestra el modo activo: Block Mode.
// Allow Mode está en pausa — se agrega cuando haya necesidad real.
struct ModePickerView: View {

    var body: some View {
        HStack {
            VStack(spacing: 3) {
                Text("Block Mode")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Bloquea lo de tu lista")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

#Preview {
    ModePickerView()
        .frame(width: 360)
        .padding()
}
