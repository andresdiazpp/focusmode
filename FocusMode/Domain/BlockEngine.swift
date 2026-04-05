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

    // Activa el bloqueo permanente: porn en /etc/hosts + DNS CleanBrowsing.
    // Se llama una sola vez desde el onboarding cuando el usuario autoriza.
    // Instala el helper primero — aquí es cuando el usuario ve el diálogo de contraseña,
    // ya con contexto de por qué lo necesita.
    // Estas capas nunca se deshacen automáticamente — ni al terminar una sesión.
    func applyPermanentBlock() async throws {
        // Cargar la lista de dominios de porn del caché en disco
        let pornDomains = blocklistFetcher.loadCached()
        guard !pornDomains.isEmpty else {
            print("[BlockEngine] Bloqueo permanente: no hay dominios en caché — descargando...")
            // Si no hay caché todavía, descargar primero
            let downloaded = try await blocklistFetcher.refreshIfNeeded()
            try await helperClient.applyPermanentHostsBlock(domains: downloaded)
            try await helperClient.applyCleanBrowsingDNS()
            print("[BlockEngine] Bloqueo permanente activado — \(downloaded.count) dominios en /etc/hosts")
            return
        }

        try await helperClient.applyPermanentHostsBlock(domains: pornDomains)
        try await helperClient.applyCleanBrowsingDNS()
        print("[BlockEngine] Bloqueo permanente activado — \(pornDomains.count) dominios en /etc/hosts")
    }

    // Activa todas las capas de bloqueo según la sesión.
    //
    // - session.mode == .block: bloquea los dominios y apps de `lists.blockWebs / blockApps`
    // - session.mode == .allow: bloquea todo EXCEPTO `lists.allowWebs / allowApps`
    //   (la lógica exacta de allow mode se implementa en Paso 10)
    //
    // La blocklist de porn siempre se incluye en /etc/hosts, sin importar el modo.
    // DNS CleanBrowsing siempre se activa, sin importar el modo.
    // permanentBlockActive: true si el usuario ya autorizó el bloqueo permanente.
    // Si es true, el DNS ya está configurado y no se toca en cada sesión.
    func activate(session: FocusSession, lists: FocusLists, permanentBlockActive: Bool) async throws {

        // Capa 2: DNS CleanBrowsing — solo si no está ya activo de forma permanente
        if !permanentBlockActive {
            try await dnsManager.applyCleanBrowsing()
        }

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
    func deactivate(permanentBlockActive: Bool) async throws {

        // Para el monitor de apps primero (es lo más rápido)
        appMonitor.stopMonitoring()

        // Quita las entradas de sesión de /etc/hosts (el bloque permanente de porn no se toca)
        try await hostsManager.removeBlock()

        // Restaura el DNS solo si no hay bloqueo permanente activo
        // Si hay bloqueo permanente, el DNS CleanBrowsing debe quedarse siempre
        if !permanentBlockActive {
            try await dnsManager.restoreDNS()
        }

        // Elimina las reglas pf y el daemon de launchd
        try await helperClient.removeFirewallBlock()

        print("[BlockEngine] Sesión desactivada — bloqueo de sesión removido")
    }
}
