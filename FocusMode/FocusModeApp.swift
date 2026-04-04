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
    @State private var sessionManager: SessionManager = {
        // Construimos las dependencias de abajo hacia arriba:
        // 1. FocusStore (persiste datos en disco)
        let store = FocusStore()

        // 2. HostsManager real — llama al PrivilegedHelper via XPC
        let helperClient = HelperClient()
        let hostsManager = HostsManager(client: helperClient)

        // Stubs pendientes (se reemplazan en Pasos 9, 10)
        let dnsManager = StubDNSManager()
        let appMonitor = StubAppMonitor()

        // 3. BlocklistFetcher — descarga y cachea la blocklist de porn
        let blocklistFetcher = BlocklistFetcher()

        // 4. BlockEngine recibe los 3 managers y el fetcher
        let blockEngine = BlockEngine(
            hostsManager: hostsManager,
            dnsManager: dnsManager,
            appMonitor: appMonitor,
            blocklistFetcher: blocklistFetcher
        )

        // 4. SessionManager recibe store y engine
        return SessionManager(store: store, blockEngine: blockEngine)
    }()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            ContentView()
                .environment(sessionManager)
            #else
            if AppDelegate.hasAccessibilityPermission() && AppDelegate.hasFullDiskAccess() {
                ContentView()
                    .environment(sessionManager)
            } else {
                PermissionsView()
            }
            #endif
        }
        .defaultSize(width: 360, height: 560)
        .windowResizability(.contentSize)
    }
}
