//
//  FocusModeApp.swift
//  FocusMode
//
//  Created by Andres Diaz on 4/4/26.
//

import SwiftUI

@main
struct FocusModeApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // SessionManager se crea una sola vez al arrancar la app.
    // Vive aquí (nivel de app) para sobrevivir cambios de vista.
    // Se pasa hacia abajo via .environment().
    // Controla si se muestra el diálogo de bloqueo permanente.
    // Se inicializa leyendo el estado guardado en disco.
    @State private var showPermanentBlockDialog = FocusStore().loadPermanentBlock().enabled == false
        && {
            let state = FocusStore().loadPermanentBlock()
            if let snoozed = state.snoozedUntil { return snoozed <= Date.now }
            return true
        }()

    @State private var sessionManager: SessionManager = {
        // Construimos las dependencias de abajo hacia arriba:
        // 1. FocusStore (persiste datos en disco)
        let store = FocusStore()

        // 2. HostsManager real — llama al PrivilegedHelper via XPC
        let helperClient = HelperClient()
        let hostsManager = HostsManager(client: helperClient)

        // 2b. DNSManager real — mismo helperClient, cambia el DNS via XPC
        let dnsManager = DNSManager(helper: helperClient)
        let appMonitor = AppMonitor()

        // 3. BlocklistFetcher — descarga y cachea la blocklist de porn
        let blocklistFetcher = BlocklistFetcher()

        // 4. BlockEngine recibe los 3 managers, el fetcher y el helperClient (para pf firewall)
        let blockEngine = BlockEngine(
            hostsManager: hostsManager,
            dnsManager: dnsManager,
            appMonitor: appMonitor,
            blocklistFetcher: blocklistFetcher,
            helperClient: helperClient
        )

        // 4. SessionManager recibe store y engine
        return SessionManager(store: store, blockEngine: blockEngine)
    }()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            mainContent
            #else
            if AppDelegate.hasAccessibilityPermission() && AppDelegate.hasFullDiskAccess() {
                mainContent
            } else {
                PermissionsView()
            }
            #endif
        }
        .defaultSize(width: 380, height: 560)
        .windowResizability(.contentSize)
    }

    // Vista principal: muestra el diálogo permanente como pantalla completa
    // (igual que PermissionsView) hasta que el usuario decida.
    // Después muestra ContentView normalmente.
    @ViewBuilder
    private var mainContent: some View {
        if showPermanentBlockDialog {
            PermanentBlockView(
                onAuthorized: { showPermanentBlockDialog = false },
                onSnoozed:    { showPermanentBlockDialog = false },
                applyBlock:   { try await sessionManager.applyPermanentBlock() },
                snooze:       { try sessionManager.snoozePermanentBlock() }
            )
        } else {
            ContentView()
                .environment(sessionManager)
                .onAppear {
                    // Re-evaluar al volver a ContentView (por si acaba de decidir)
                    showPermanentBlockDialog = sessionManager.shouldShowPermanentBlockDialog()
                }
        }
    }
}
