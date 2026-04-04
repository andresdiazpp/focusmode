// HostsManaging.swift
// Contrato para quien sabe escribir en /etc/hosts.
//
// BlockEngine usa este protocolo — no HostsManager directamente.
// Así podemos cambiar la implementación sin tocar BlockEngine.

import Foundation

protocol HostsManaging {

    // Escribe los dominios bloqueados en /etc/hosts.
    // Cada dominio queda redirigido a 0.0.0.0.
    func applyBlock(domains: [String]) async throws

    // Borra las entradas que FocusMode escribió en /etc/hosts.
    // Las entradas del sistema y de otros programas no se tocan.
    func removeBlock() async throws
}
