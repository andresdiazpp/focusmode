// StubDNSManager.swift
// Implementación temporal de DNSManaging.
//
// No cambia el DNS real — solo sirve para que la app compile.
// Se reemplaza por DNSManager.swift en el Paso 9.

import Foundation

final class StubDNSManager: DNSManaging {

    func applyCleanBrowsing() async throws {
        // Paso 9: cambiar DNS a CleanBrowsing via XPC (networksetup)
        print("[StubDNSManager] applyCleanBrowsing (sin efecto real)")
    }

    func restoreDNS() async throws {
        // Paso 9: restaurar el DNS original via XPC
        print("[StubDNSManager] restoreDNS (sin efecto real)")
    }
}
