// PermanentBlockView.swift
// Diálogo que aparece al arrancar hasta que el usuario tome una decisión.
//
// El usuario puede:
//   - Autorizar el bloqueo permanente → se activa y nunca se vuelve a mostrar
//   - Posponer por un mes → se vuelve a mostrar en 30 días

import SwiftUI

struct PermanentBlockView: View {

    // Se llama cuando el bloqueo permanente se activó exitosamente
    var onAuthorized: () -> Void
    // Se llama cuando el usuario elige posponer
    var onSnoozed: () -> Void
    // Se llama para ejecutar el bloqueo permanente (vive en SessionManager)
    var applyBlock: () async throws -> Void
    var snooze: () throws -> Void

    // true mientras se están escribiendo los 657k dominios en /etc/hosts
    @State private var isApplying = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    // Ejemplos de lo que se bloquea — concretos para que el usuario entienda
    private let examples = [
        ("🔞", "Pornografía", "Millones de sitios bloqueados permanentemente"),
        ("🎰", "Apuestas en línea", "Casinos, apuestas deportivas, loterías"),
        ("💊", "Drogas", "Sitios de venta y promoción de sustancias"),
        ("🔓", "Proxies y VPNs", "Herramientas para saltarse los bloqueos"),
    ]

    var body: some View {
        if showSuccess {
            successView
        } else {
            mainView
        }
    }

    // Pantalla de confirmación — aparece después de activar el bloqueo
    private var successView: some View {
        VStack(spacing: 20) {
            Text("✅")
                .font(.system(size: 52))

            Text("Listo. Ya estás protegido.")
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)

            Text("Los sitios de pornografía, apuestas, drogas y proxies están bloqueados permanentemente. No se desactivan aunque cierres la app.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Empezar") {
                onAuthorized()
            }
        }
        .padding(32)
        .frame(width: 380)
    }

    private var mainView: some View {
        VStack(spacing: 0) {

            // --- Encabezado ---
            VStack(spacing: 12) {
                Text("🎯")
                    .font(.system(size: 48))

                Text("FocusMode existe para ayudarte a enfocarte en lo que más importa")
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Hay cosas que deberían estar bloqueadas siempre — no solo cuando tienes una sesión activa. Sin excepciones.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            // --- Lista de lo que se bloquea ---
            VStack(spacing: 0) {
                Text("Esto quedaría bloqueado permanentemente:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                ForEach(examples, id: \.1) { emoji, title, subtitle in
                    HStack(spacing: 12) {
                        Text(emoji)
                            .font(.system(size: 20))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 13, weight: .medium))
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 8)

            Divider()

            // --- Error si algo falló ---
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }

            // --- Botones ---
            VStack(spacing: 10) {
                // Botón principal: autorizar
                // Estilo manual para que el color azul no desaparezca
                // cuando la ventana pierde el foco (comportamiento de macOS).
                PrimaryButton(
                    title: "Sí, bloquear siempre",
                    isLoading: isApplying,
                    loadingTitle: "Activando..."
                ) {
                    guard !isApplying else { return }
                    isApplying = true
                    errorMessage = nil
                    Task {
                        do {
                            try await applyBlock()
                            showSuccess = true
                        } catch {
                            isApplying = false
                            errorMessage = "FocusMode necesita tu contraseña de Mac para instalar el componente que bloquea los sitios. Presiona el botón de nuevo y acepta cuando macOS te lo pida."
                        }
                    }
                }

                // Botón secundario: posponer
                Button {
                    try? snooze()
                    onSnoozed()
                } label: {
                    Text("No preguntar este mes")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isApplying)
            }
            .padding(24)
        }
        .frame(width: 380)
    }
}

#Preview {
    PermanentBlockView(
        onAuthorized: { print("Autorizado") },
        onSnoozed: { print("Pospuesto") },
        applyBlock: { try await Task.sleep(nanoseconds: 2_000_000_000) },
        snooze: {}
    )
}
