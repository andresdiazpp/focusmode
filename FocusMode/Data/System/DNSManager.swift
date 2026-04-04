// DNSManager.swift
// Implementación real de DNSManaging.
//
// Habla con el PrivilegedHelper via XPC para cambiar el DNS del sistema.
// El helper necesita root — la app no puede hacerlo directamente.

import Foundation

final class DNSManager: DNSManaging {

    private let helper: HelperClient

    init(helper: HelperClient) {
        self.helper = helper
    }

    // Cambia el DNS de todas las interfaces activas a CleanBrowsing.
    // CleanBrowsing bloquea sitios adultos y VPNs a nivel de DNS.
    func applyCleanBrowsing() async throws {
        try await helper.applyCleanBrowsingDNS()
    }

    // Restaura el DNS original del usuario.
    // El helper guarda el DNS anterior antes de cambiarlo.
    func restoreDNS() async throws {
        try await helper.restoreOriginalDNS()
    }
}
