//
//  ModePickerView.swift
//  FocusMode
//

import SwiftUI

// ModePickerView muestra dos botones: Block Mode y Allow Mode.
// El modo seleccionado se ve destacado; el otro se ve apagado.
struct ModePickerView: View {

    // Binding: el valor vive en HomeViewModel, este componente solo lo muestra y cambia
    @Binding var selectedMode: SessionMode

    var body: some View {
        HStack(spacing: 0) {
            // Botón Block Mode
            modeButton(
                title: "Block Mode",
                subtitle: "Bloquea lo de tu lista",
                mode: .block
            )

            Divider().frame(height: 50)

            // Botón Allow Mode
            modeButton(
                title: "Allow Mode",
                subtitle: "Solo permite tu lista",
                mode: .allow
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    // Construye un botón de modo individual
    @ViewBuilder
    private func modeButton(title: String, subtitle: String, mode: SessionMode) -> some View {
        let isSelected = selectedMode == mode

        Button {
            selectedMode = mode
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // Fondo del botón seleccionado
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.1)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModePickerView(selectedMode: .constant(.block))
        .frame(width: 360)
        .padding()
}
