// HostsManager.swift
// Implementación real de HostsManaging.
// Delega las operaciones de escritura al PrivilegedHelper via XPC,
// porque /etc/hosts requiere permisos de root.

import Foundation

final class HostsManager: HostsManaging {

    private let client: HelperClient

    init(client: HelperClient) {
        self.client = client
    }

    // Pide al helper que escriba los dominios en /etc/hosts.
    // El helper corre como root y puede escribir archivos del sistema.
    func applyBlock(domains: [String]) async throws {
        try await client.applyHostsBlock(domains: domains)
    }

    // Pide al helper que borre las entradas que FocusMode escribió.
    // Las entradas del sistema y de otros programas no se tocan.
    func removeBlock() async throws {
        try await client.removeHostsBlock()
    }
}
