// FocusSession.swift
// Representa una sesión de bloqueo activa.
// Se guarda en disco para sobrevivir cierres de app y reinicios del Mac.

import Foundation

struct FocusSession: Codable {
    var mode: SessionMode
    var endsAt: Date  // hora exacta en que termina el bloqueo

    // isActive se calcula en el momento — no se guarda.
    // Esto evita el bug de tener isActive=true pero la hora ya pasó.
    var isActive: Bool { Date.now < endsAt }
}
