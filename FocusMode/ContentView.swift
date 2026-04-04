//
//  ContentView.swift
//  FocusMode
//

import SwiftUI

// ContentView es el punto de entrada de la pantalla principal.
// Simplemente muestra HomeView — aquí no vive lógica ni estado.
struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
}
