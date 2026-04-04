//
//  HomeViewModel.swift
//  FocusMode
//

import SwiftUI

// HomeViewModel guarda el estado de la pantalla principal.
// No tiene lógica de bloqueo — eso viene en pasos posteriores.
@Observable
final class HomeViewModel {

    // --- Modo seleccionado ---
    // .block = bloquea lo que está en la lista
    // .allow = solo permite lo que está en la lista
    var selectedMode: SessionMode = .block

    // --- Timer ---
    // Dos maneras de elegir cuándo termina la sesión:
    // byDuration = el usuario elige cuántas horas/minutos
    // byTime     = el usuario elige una hora exacta
    enum TimerInputMode {
        case byDuration
        case byTime
    }
    var timerInputMode: TimerInputMode = .byDuration

    // Duración elegida (cuando timerInputMode == .byDuration)
    var selectedHours: Int = 0
    var selectedMinutes: Int = 0

    // Hora exacta elegida (cuando timerInputMode == .byTime)
    var selectedEndDate: Date = Calendar.current.date(
        byAdding: .hour, value: 1, to: .now
    ) ?? .now

    // --- Estado de la sesión ---
    // Por ahora solo es visual. La lógica real llega en el Paso 5.
    var sessionIsActive: Bool = false

    // --- Computed: fecha de fin según el modo de timer ---
    var computedEndDate: Date {
        switch timerInputMode {
        case .byDuration:
            // Suma horas y minutos al momento actual
            let seconds = TimeInterval(selectedHours * 3600 + selectedMinutes * 60)
            return Date.now.addingTimeInterval(seconds)
        case .byTime:
            return selectedEndDate
        }
    }

    // --- Acción del botón principal ---
    func toggleSession() {
        // Por ahora solo cambia el estado visual
        sessionIsActive.toggle()
    }
}
