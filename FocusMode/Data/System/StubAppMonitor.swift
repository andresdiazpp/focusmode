// StubAppMonitor.swift
// Implementación temporal de AppMonitoring.
//
// No observa ni cierra nada — solo sirve para que la app compile.
// Se reemplaza por AppMonitor.swift en el Paso 10.

import Foundation

final class StubAppMonitor: AppMonitoring {

    func startMonitoring(blockedBundleIDs: [String]) {
        // Paso 10: observar NSWorkspace y cerrar apps bloqueadas
        print("[StubAppMonitor] startMonitoring: \(blockedBundleIDs.count) apps (sin efecto real)")
    }

    func stopMonitoring() {
        // Paso 10: dejar de observar
        print("[StubAppMonitor] stopMonitoring (sin efecto real)")
    }
}
