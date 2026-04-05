// AppDelegate.swift
// Se ejecuta cuando la app arranca.
// Verifica si los permisos necesarios están dados.
// Si falta alguno, muestra la pantalla de onboarding.

import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Trae la app al frente y centra la ventana al abrir
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.center()

        // NO instalamos el helper aquí — se instala cuando el usuario hace click en
        // "Sí, bloquear siempre" en el onboarding. Así la clave aparece con contexto.
        // Si el helper ya estaba instalado (usuario recurrente), se instala silenciosamente
        // porque los hashes coinciden y no hay nada que hacer.

        // Refresca la blocklist de porn si pasaron más de 7 días.
        // Se lanza en background — no bloquea el arranque de la app.
        Task {
            do {
                let domains = try await BlocklistFetcher().refreshIfNeeded()
                print("[AppDelegate] Blocklist lista — \(domains.count) dominios")
            } catch {
                print("[AppDelegate] No se pudo refrescar la blocklist: \(error)")
            }
        }
    }

    // Verifica si la app tiene permiso de Accessibility.
    // Accessibility permite observar qué apps están abiertas y cerrarlas.
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    // Verifica si la app tiene Full Disk Access.
    // Full Disk Access permite leer y escribir /etc/hosts.
    static func hasFullDiskAccess() -> Bool {
        let hostsPath = "/etc/hosts"
        return FileManager.default.isReadableFile(atPath: hostsPath)
    }
}
