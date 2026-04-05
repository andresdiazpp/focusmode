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

    // MARK: - Bloqueo permanente

    // Activa el bloqueo permanente de porn y DNS.
    // Se llama una sola vez desde el onboarding cuando el usuario autoriza.
    func applyPermanentBlock() async throws {
        try await blockEngine.applyPermanentBlock()
        try store.savePermanentBlock(enabled: true, snoozedUntil: nil)
    }

    // Pospone el diálogo de bloqueo permanente por 30 días.
    func snoozePermanentBlock() throws {
        let until = Calendar.current.date(byAdding: .day, value: 30, to: Date.now) ?? Date.now
        try store.savePermanentBlock(enabled: false, snoozedUntil: until)
    }

    // Devuelve true si el diálogo debe mostrarse:
    // - si nunca se autorizó, Y
    // - si no hay snooze activo (o el snooze ya venció)
    func shouldShowPermanentBlockDialog() -> Bool {
        let state = store.loadPermanentBlock()
        if state.enabled { return false }
        if let snoozedUntil = state.snoozedUntil, snoozedUntil > Date.now { return false }
        return true
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

        // 3. Crear la sesión en memoria (todavía no se guarda en disco)
        let session = FocusSession(mode: mode, endsAt: endsAt)

        // 4. Activar las capas de bloqueo — si falla, no se guarda nada
        let permanentActive = store.loadPermanentBlock().enabled
        log("[DEBUG] SessionManager: llamando blockEngine.activate — permanentActive=\(permanentActive)")
        try await blockEngine.activate(session: session, lists: lists, permanentBlockActive: permanentActive)
        log("[DEBUG] SessionManager: blockEngine.activate completó OK")

        // 5. Solo si el bloqueo fue exitoso: guardar sesión y actualizar la UI
        try store.saveSession(session)
        activeSession = session
        log("[DEBUG] SessionManager: sesión guardada y publicada")

        // 6. Programar el timer de expiración
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
        let permanentActive = store.loadPermanentBlock().enabled
        try await blockEngine.deactivate(permanentBlockActive: permanentActive)
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
                let permanentActive = store.loadPermanentBlock().enabled
                try? await blockEngine.deactivate(permanentBlockActive: permanentActive)
                store.clearSession()
            }
        }
    }
}
