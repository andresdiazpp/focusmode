// AppDelegate.swift
// Se ejecuta cuando la app arranca.
// Verifica si los permisos necesarios están dados.
// Si falta alguno, muestra la pantalla de onboarding.

import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Si falta algún permiso, la pantalla de onboarding se muestra
        // automáticamente porque PermissionsView verifica el estado al cargar.
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
