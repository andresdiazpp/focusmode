// DNSManaging.swift
// Contrato para quien sabe cambiar el DNS del sistema.
//
// Durante una sesión: DNS = CleanBrowsing (bloquea adultos y VPNs).
// Al terminar: DNS vuelve al que tenía el usuario antes.

import Foundation

protocol DNSManaging {

    // Cambia el DNS de todas las interfaces activas a CleanBrowsing.
    // Guarda el DNS original para poder restaurarlo después.
    func applyCleanBrowsing() async throws

    // Restaura el DNS que tenía el usuario antes de activar FocusMode.
    func restoreDNS() async throws
}
