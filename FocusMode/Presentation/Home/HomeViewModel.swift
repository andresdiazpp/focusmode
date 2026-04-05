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

    // --- Estado de carga ---
    // true mientras se está activando la sesión (esperando al helper y al bloqueo)
    var isStarting: Bool = false

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
        isStarting = true

        Task {
            do {
                log("[DEBUG] ViewModel: llamando activateSession modo=block endsAt=\(computedEndDate)")
                try await sessionManager.activateSession(
                    mode: .block,
                    endsAt: computedEndDate,
                    lists: lists
                )
                log("[DEBUG] ViewModel: activateSession completó OK")
                // Sesión activada — quitar el spinner
                await MainActor.run { isStarting = false }
            } catch FocusModeError.invalidEndDate {
                log("[DEBUG] ViewModel: error invalidEndDate")
                await MainActor.run {
                    isStarting = false
                    errorMessage = "La hora de fin ya pasó. Elige una hora en el futuro."
                }
            } catch FocusModeError.licenseRequired {
                log("[DEBUG] ViewModel: error licenseRequired")
                await MainActor.run {
                    isStarting = false
                    errorMessage = "Block Mode es de pago. Activa tu licencia."
                }
            } catch is HelperClientError {
                log("[DEBUG] ViewModel: error HelperClientError")
                await MainActor.run {
                    isStarting = false
                    errorMessage = "Para bloquear sitios, FocusMode necesita instalar un componente que requiere tu contraseña de Mac. Presiona \"Iniciar sesión\" de nuevo y acepta el diálogo que aparece."
                }
            } catch {
                log("[DEBUG] ViewModel: error genérico — \(type(of: error)) — \(error)")
                await MainActor.run {
                    isStarting = false
                    errorMessage = "No se pudo activar la sesión: \(error.localizedDescription)"
                }
            }
        }
    }
}
