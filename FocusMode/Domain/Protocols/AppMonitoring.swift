// AppMonitoring.swift
// Contrato para quien observa qué apps están abiertas.
//
// Cuando una app bloqueada se abre, AppMonitor la cierra de inmediato.
// Cuando se termina la sesión, AppMonitor deja de observar.

import Foundation

protocol AppMonitoring {

    // Empieza a observar. Si una app de `bundleIDs` se abre, la cierra.
    func startMonitoring(blockedBundleIDs: [String])

    // Para de observar. Se llama cuando la sesión termina.
    func stopMonitoring()
}
