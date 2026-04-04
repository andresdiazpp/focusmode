//
//  HomeViewModel.swift
//  FocusMode
//

import SwiftUI

// HomeViewModel guarda el estado de la UI de la pantalla principal.
// La lógica de bloqueo real vive en SessionManager.
@Observable
final class HomeViewModel {

    // El SessionManager es la fuente de verdad de si hay sesión activa.
    // HomeViewModel lo llama para activar/desactivar.
    private let sessionManager: SessionManager

    // --- Modo seleccionado en la UI ---
    var selectedMode: SessionMode = .block

    // --- Timer ---
    enum TimerInputMode {
        case byDuration
        case byTime
    }
    var timerInputMode: TimerInputMode = .byDuration
    var selectedHours: Int = 0
    var selectedMinutes: Int = 0
    var selectedEndDate: Date = Calendar.current.date(
        byAdding: .hour, value: 1, to: .now
    ) ?? .now

    // --- Error a mostrar al usuario ---
    // Se llena si activateSession falla.
    var errorMessage: String? = nil

    // --- Computed: ¿hay sesión activa? ---
    // Se deriva del SessionManager — no tiene estado propio.
    var sessionIsActive: Bool {
        sessionManager.activeSession != nil
    }

    // --- Computed: fecha de fin de la sesión activa ---
    // Si hay sesión activa, muestra su hora real. Si no, la proyectada.
    var displayEndDate: Date {
        sessionManager.activeSession?.endsAt ?? computedEndDate
    }

    // --- Computed: modo de la sesión activa ---
    // Muestra el modo real de la sesión activa (no el selector de la UI).
    var displayMode: SessionMode {
        sessionManager.activeSession?.mode ?? selectedMode
    }

    // --- Computed: fecha de fin según la UI (antes de activar) ---
    var computedEndDate: Date {
        switch timerInputMode {
        case .byDuration:
            let seconds = TimeInterval(selectedHours * 3600 + selectedMinutes * 60)
            return Date.now.addingTimeInterval(seconds)
        case .byTime:
            return selectedEndDate
        }
    }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    // --- Acción del botón principal ---
    // La sesión es irrevocable — no hay cancelación.
    // El botón solo sirve para activar.
    func startSession(lists: FocusLists) {

        // Validación rápida antes de llamar al SessionManager
        // (el SessionManager también valida, pero aquí damos feedback inmediato)
        guard computedEndDate > Date.now else {
            errorMessage = "La hora de fin ya pasó. Elige una hora en el futuro."
            return
        }

        errorMessage = nil

        Task {
            do {
                try await sessionManager.activateSession(
                    mode: selectedMode,
                    endsAt: computedEndDate,
                    lists: lists
                )
            } catch FocusModeError.invalidEndDate {
                await MainActor.run {
                    errorMessage = "La hora de fin ya pasó. Elige una hora en el futuro."
                }
            } catch FocusModeError.licenseRequired {
                await MainActor.run {
                    errorMessage = "Block Mode y Allow Mode son de pago. Activa tu licencia."
                }
            } catch {
                await MainActor.run {
                    errorMessage = "No se pudo activar la sesión: \(error.localizedDescription)"
                }
            }
        }
    }
}
