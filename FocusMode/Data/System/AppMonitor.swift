// AppMonitor.swift
// Implementación real de AppMonitoring.
//
// Escucha notificaciones de NSWorkspace cada vez que una app se abre.
// Si el bundle ID de esa app está en la lista de bloqueadas, la cierra de inmediato.
// No necesita XPC — NSWorkspace y NSRunningApplication están disponibles en el proceso principal.

import AppKit

final class AppMonitor: AppMonitoring {

    // IDs de las apps bloqueadas durante la sesión activa.
    // Set para que la búsqueda sea O(1).
    private var blockedIDs: Set<String> = []

    // Token del observer — lo guardamos para poder quitarlo después.
    private var observer: NSObjectProtocol?

    // Empieza a escuchar lanzamientos de apps.
    // Cualquier app que se abra y esté en `blockedBundleIDs` se cierra al instante.
    func startMonitoring(blockedBundleIDs: [String]) {
        blockedIDs = Set(blockedBundleIDs)
        guard !blockedIDs.isEmpty else { return }

        // NSWorkspace.didLaunchApplicationNotification se dispara cada vez
        // que el sistema operativo abre una nueva aplicación.
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppLaunch(notification)
        }

        log("[AppMonitor] Monitoreando \(blockedIDs.count) apps")
    }

    // Para de escuchar. Se llama cuando la sesión termina.
    func stopMonitoring() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        blockedIDs = []
        log("[AppMonitor] Monitoreo detenido")
    }

    // MARK: - Privado

    // Se llama cada vez que se abre una app.
    // Si está bloqueada, la termina.
    private func handleAppLaunch(_ notification: Notification) {
        // El diccionario de la notificación contiene la app que se acaba de abrir.
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
              let bundleID = app.bundleIdentifier
        else { return }

        guard blockedIDs.contains(bundleID) else { return }

        // forceTerminate() cierra la app sin darle tiempo de reaccionar.
        // Es equivalente a "Force Quit" del menú de Apple.
        app.forceTerminate()
        log("[AppMonitor] App bloqueada cerrada: \(bundleID)")
    }
}
