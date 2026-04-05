// SessionStoring.swift
// Contrato que define qué operaciones de disco necesita el Dominio.
//
// El Dominio no sabe si los datos se guardan en JSON, SQLite o la nube.
// Solo sabe que puede pedir guardar, cargar y borrar.

import Foundation

protocol SessionStoring {

    // Guarda la sesión activa en disco
    func saveSession(_ session: FocusSession) throws

    // Lee la sesión guardada. Nil si no existe.
    func loadSession() -> FocusSession?

    // Borra la sesión (se llama cuando el timer expira o se cancela)
    func clearSession()

    // Guarda las 4 listas
    func saveLists(_ lists: FocusLists) throws

    // Lee las listas. Devuelve listas vacías si no existen.
    func loadLists() -> FocusLists

    // Guarda si el usuario autorizó el bloqueo permanente y hasta cuándo está pospuesto
    func savePermanentBlock(enabled: Bool, snoozedUntil: Date?) throws

    // Lee el estado del bloqueo permanente
    func loadPermanentBlock() -> (enabled: Bool, snoozedUntil: Date?)
}
