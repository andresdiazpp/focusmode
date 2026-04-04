// StubHostsManager.swift
// Implementación temporal de HostsManaging.
//
// No hace nada real — solo sirve para que la app compile y funcione
// mientras el XPC Helper no existe todavía.
// Se reemplaza por HostsManager.swift en el Paso 7.

import Foundation

final class StubHostsManager: HostsManaging {

    func applyBlock(domains: [String]) async throws {
        // Paso 7: escribir los dominios en /etc/hosts via XPC
        print("[StubHostsManager] applyBlock: \(domains.count) dominios (sin efecto real)")
    }

    func removeBlock() async throws {
        // Paso 7: borrar las entradas de FocusMode en /etc/hosts via XPC
        print("[StubHostsManager] removeBlock (sin efecto real)")
    }
}
