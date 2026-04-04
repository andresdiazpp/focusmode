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

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // En desarrollo siempre mostramos la pantalla principal
            // para no depender de permisos del sistema
            ContentView()
            #else
            // En producción verificamos los permisos reales
            if AppDelegate.hasAccessibilityPermission() && AppDelegate.hasFullDiskAccess() {
                ContentView()
            } else {
                PermissionsView()
            }
            #endif
        }
    }
}
