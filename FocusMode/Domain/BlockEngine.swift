// BlockEngine.swift
// Coordina las 3 capas de bloqueo de sistema.
//
// BlockEngine no sabe cómo se bloquea cada capa — eso lo saben
// HostsManager, DNSManager y AppMonitor. BlockEngine solo les dice
// cuándo activar y cuándo parar.
//
// Recibe las implementaciones por initializer (inyección de dependencias).
// Esto permite usarlo con implementaciones reales o de prueba.

import Foundation

final class BlockEngine {

    // Las 3 capas de bloqueo — cada una implementa su protocolo
    private let hostsManager: HostsManaging
    private let dnsManager: DNSManaging
    private let appMonitor: AppMonitoring

    init(
        hostsManager: HostsManaging,
        dnsManager: DNSManaging,
        appMonitor: AppMonitoring
    ) {
        self.hostsManager = hostsManager
        self.dnsManager = dnsManager
        self.appMonitor = appMonitor
    }

    // Activa todas las capas de bloqueo según la sesión.
    //
    // - session.mode == .block: bloquea los dominios y apps de `lists.blockWebs / blockApps`
    // - session.mode == .allow: bloquea todo EXCEPTO `lists.allowWebs / allowApps`
    //   (la lógica exacta de allow mode se implementa en Paso 7/10)
    //
    // Clean Mode (DNS) siempre se activa, sin importar el modo.
    func activate(session: FocusSession, lists: FocusLists) async throws {

        // Capa 2: DNS CleanBrowsing — siempre activo
        try await dnsManager.applyCleanBrowsing()

        // Capa 1: hosts — dominios a bloquear según el modo
        let domainsToBlock: [String]
        switch session.mode {
        case .block:
            // Block Mode: bloquea solo los dominios de la lista del usuario
            domainsToBlock = lists.blockWebs
        case .allow:
            // Allow Mode: la lógica completa se implementa en Paso 7
            // Por ahora no bloqueamos nada en hosts (el DNS ya cubre lo básico)
            domainsToBlock = []
        }

        if !domainsToBlock.isEmpty {
            try await hostsManager.applyBlock(domains: domainsToBlock)
        }

        print("[BlockEngine] \(session.mode == .block ? "Block" : "Allow") Mode activado — hosts bloqueados: \(domainsToBlock.count)")

        // Capa 4: cierre de apps — según el modo
        let appsToBlock: [String]
        switch session.mode {
        case .block:
            appsToBlock = lists.blockApps
        case .allow:
            // Allow Mode: la lógica completa se implementa en Paso 10
            appsToBlock = []
        }

        if !appsToBlock.isEmpty {
            appMonitor.startMonitoring(blockedBundleIDs: appsToBlock)
        }
    }

    // Para todas las capas de bloqueo.
    // Se llama cuando el timer expira o (en versión futura) si el usuario tiene
    // una contraseña de emergencia.
    func deactivate() async throws {

        // Para el monitor de apps primero (es lo más rápido)
        appMonitor.stopMonitoring()

        // Quita las entradas de hosts
        try await hostsManager.removeBlock()

        // Restaura el DNS original
        try await dnsManager.restoreDNS()

        print("[BlockEngine] Sesión desactivada — bloqueo removido")
    }
}
