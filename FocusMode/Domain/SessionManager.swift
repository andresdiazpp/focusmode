// SessionManager.swift
// Orquesta el ciclo de vida de una sesión de bloqueo.
//
// Flujo de activación:
//   1. Verifica que la fecha de fin sea futura
//   2. Verifica la licencia (si el modo lo requiere)
//   3. Guarda la sesión en disco
//   4. Le dice a BlockEngine que active las capas de bloqueo
//   5. Programa un timer para desactivar cuando expire
//
// Flujo de desactivación (al expirar el timer):
//   1. Le dice a BlockEngine que desactive
//   2. Borra la sesión del disco
//
// Nota: la sesión es irrevocable mientras el timer corre.
// No hay función pública de cancelación — eso es intencional.

import Foundation

@Observable
final class SessionManager {

    // La sesión activa ahora mismo. Nil si no hay sesión.
    private(set) var activeSession: FocusSession?

    // Las 3 dependencias — se inyectan desde afuera
    private let store: SessionStoring
    private let blockEngine: BlockEngine

    // Timer que desactiva la sesión cuando expira
    private var expirationTimer: Timer?

    init(store: SessionStoring, blockEngine: BlockEngine) {
        self.store = store
        self.blockEngine = blockEngine

        // Al arrancar: restaura sesión si había una activa
        restoreSessionIfNeeded()
    }

    // MARK: - Activación

    // Activa una sesión de bloqueo.
    //
    // Puede lanzar:
    //   - FocusModeError.invalidEndDate si endsAt ya pasó
    //   - FocusModeError.licenseRequired si el modo es de pago y no hay licencia
    //   - Errores de BlockEngine si el sistema no puede bloquearse
    func activateSession(mode: SessionMode, endsAt: Date, lists: FocusLists) async throws {

        // 1. La fecha de fin tiene que ser en el futuro
        guard endsAt > Date.now else {
            throw FocusModeError.invalidEndDate
        }

        // 2. Block Mode y Allow Mode son de pago — verificar licencia
        // (LicenseValidator se implementa en el paso de monetización)
        // Por ahora: siempre permitido. La línea de abajo se descomenta después.
        // guard LicenseValidator.isValid() else { throw FocusModeError.licenseRequired }

        // 3. Crear y guardar la sesión
        let session = FocusSession(mode: mode, endsAt: endsAt)
        try store.saveSession(session)
        activeSession = session

        // 4. Activar las capas de bloqueo
        try await blockEngine.activate(session: session, lists: lists)

        // 5. Programar el timer de expiración
        scheduleExpiration(at: endsAt)
    }

    // MARK: - Timer de expiración

    private func scheduleExpiration(at date: Date) {
        expirationTimer?.invalidate()

        let interval = date.timeIntervalSinceNow
        // Si por alguna razón el intervalo es negativo, desactivar ahora
        guard interval > 0 else {
            Task { try? await deactivateSession() }
            return
        }

        expirationTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            Task { try? await self?.deactivateSession() }
        }
    }

    // MARK: - Desactivación

    // Se llama solo cuando el timer expira.
    // No es pública — la sesión es irrevocable mientras corre.
    private func deactivateSession() async throws {
        try await blockEngine.deactivate()
        store.clearSession()
        expirationTimer?.invalidate()
        expirationTimer = nil

        // Volvemos al hilo principal para actualizar la UI
        await MainActor.run {
            activeSession = nil
        }
    }

    // MARK: - Restauración al arrancar

    // Si la app se cerró con una sesión activa, la retoma.
    // Si la sesión ya expiró (el timer corrió sin la app abierta),
    // las capas 1, 2 y 3 ya están activas en el sistema — hay que limpiarlas.
    private func restoreSessionIfNeeded() {
        guard let saved = store.loadSession() else { return }

        if saved.isActive {
            // La sesión sigue vigente — restaurar estado y reprogramar timer
            activeSession = saved
            scheduleExpiration(at: saved.endsAt)
            // Nota: BlockEngine ya está activo (las capas persisten en el sistema).
            // No es necesario volver a llamar activate().
        } else {
            // La sesión expiró mientras la app estaba cerrada — limpiar
            Task {
                try? await blockEngine.deactivate()
                store.clearSession()
            }
        }
    }
}
