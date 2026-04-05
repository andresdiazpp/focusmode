// PrimaryButton.swift
// Botón principal de la app con fondo azul permanente.
//
// Por qué existe este componente:
// En macOS, .buttonStyle(.borderedProminent) pierde su color azul cuando
// la ventana pierde el foco — el texto blanco queda invisible sobre fondo blanco.
// Este componente dibuja el fondo manualmente con Color.accentColor,
// que no depende del estado de foco de la ventana.
//
// Regla: cualquier botón azul prominente en esta app usa PrimaryButton,
// nunca .buttonStyle(.borderedProminent).

import SwiftUI

struct PrimaryButton: View {

    let title: String
    var isLoading: Bool = false
    var loadingTitle: String = "Cargando..."
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text(loadingTitle)
                    }
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color.accentColor.opacity(isDisabled ? 0.5 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Iniciar sesión") {}
        PrimaryButton(title: "Activando...", isLoading: true, loadingTitle: "Activando...") {}
        PrimaryButton(title: "Desactivado", isDisabled: true) {}
    }
    .padding()
    .frame(width: 360)
}
