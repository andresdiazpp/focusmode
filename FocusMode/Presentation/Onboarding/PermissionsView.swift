// PermissionsView.swift
// Pantalla de onboarding que muestra el estado de cada permiso.
// El usuario ve exactamente qué le falta y puede ir directo a darlo con un clic.

import SwiftUI

struct PermissionsView: View {

    // Estado de cada permiso — se verifica cada vez que la pantalla aparece
    @State private var hasAccessibility = false
    @State private var hasFullDisk = false

    var allGranted: Bool {
        hasAccessibility && hasFullDisk
    }

    var body: some View {
        VStack(spacing: 24) {
            // Título
            VStack(spacing: 8) {
                Text("FocusMode necesita permisos")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Sin estos permisos la app no puede bloquear nada.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Lista de permisos
            VStack(spacing: 12) {
                PermissionRow(
                    icon: "lock.shield",
                    title: "Full Disk Access",
                    description: "Para leer y escribir /etc/hosts",
                    isGranted: hasFullDisk,
                    action: openFullDiskAccess
                )

                PermissionRow(
                    icon: "eye",
                    title: "Accessibility",
                    description: "Para detectar y cerrar apps bloqueadas",
                    isGranted: hasAccessibility,
                    action: openAccessibility
                )
            }

            // Botón continuar — solo activo cuando todos los permisos están dados
            Button(action: {}) {
                Text(allGranted ? "Continuar" : "Esperando permisos...")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!allGranted)
        }
        .padding(32)
        .frame(width: 420)
        // Verifica permisos al aparecer la pantalla y cada vez que la app vuelve al frente
        .onAppear(perform: checkPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
    }

    // Lee el estado actual de cada permiso
    private func checkPermissions() {
        hasAccessibility = AppDelegate.hasAccessibilityPermission()
        hasFullDisk = AppDelegate.hasFullDiskAccess()
    }

    // Abre Preferencias del Sistema en la sección de Full Disk Access
    private func openFullDiskAccess() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    // Abre Preferencias del Sistema en la sección de Accessibility
    private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

// MARK: - Fila individual de permiso

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Ícono del permiso
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(.secondary)

            // Nombre y descripción
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Estado: check verde si está dado, botón si no
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button("Dar permiso", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    PermissionsView()
}
