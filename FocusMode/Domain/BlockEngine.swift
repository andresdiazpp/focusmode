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

    // Blocklist de pornografía (StevenBlack + Blocklist Project, cacheada en disco)
    private let blocklistFetcher: BlocklistFetcher

    // Cliente XPC para hablar con el helper (capa 4: firewall pf)
    private let helperClient: HelperClient

    init(
        hostsManager: HostsManaging,
        dnsManager: DNSManaging,
        appMonitor: AppMonitoring,
        blocklistFetcher: BlocklistFetcher,
        helperClient: HelperClient
    ) {
        self.hostsManager = hostsManager
        self.dnsManager = dnsManager
        self.appMonitor = appMonitor
        self.blocklistFetcher = blocklistFetcher
        self.helperClient = helperClient
    }

    // Activa todas las capas de bloqueo según la sesión.
    //
    // - session.mode == .block: bloquea los dominios y apps de `lists.blockWebs / blockApps`
    // - session.mode == .allow: bloquea todo EXCEPTO `lists.allowWebs / allowApps`
    //   (la lógica exacta de allow mode se implementa en Paso 10)
    //
    // La blocklist de porn siempre se incluye en /etc/hosts, sin importar el modo.
    // DNS CleanBrowsing siempre se activa, sin importar el modo.
    func activate(session: FocusSession, lists: FocusLists) async throws {

        // Capa 2: DNS CleanBrowsing — siempre activo
        try await dnsManager.applyCleanBrowsing()

        // Dominios del usuario según el modo
        let userDomains: [String]
        switch session.mode {
        case .block:
            userDomains = lists.blockWebs
        case .allow:
            userDomains = []
        }

        // Capa 1: hosts — solo dominios del usuario por sesión.
        // La blocklist de porn (657k dominios) ya está escrita en /etc/hosts
        // desde el arranque (BlocklistFetcher). Reescribirla en cada sesión
        // toma más de 1 minuto via XPC y rompería el timer.
        if !userDomains.isEmpty {
            try await hostsManager.applyBlock(domains: userDomains)
        }

        // Capa 3: firewall pf — bloquea a nivel de red, persiste tras reinicios
        if !userDomains.isEmpty {
            try await helperClient.applyFirewallBlock(domains: userDomains)
        }

        print("[BlockEngine] \(session.mode == .block ? "Block" : "Allow") Mode activado — usuario: \(userDomains.count) dominios")

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

        // Elimina las reglas pf y el daemon de launchd
        try await helperClient.removeFirewallBlock()

        print("[BlockEngine] Sesión desactivada — bloqueo removido")
    }
}
