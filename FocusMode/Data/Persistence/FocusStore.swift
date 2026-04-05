// FocusStore.swift
// Lee y escribe los datos de la app en disco.
//
// Los datos se guardan en ~/Library/Application Support/FocusMode/
// y NO en UserDefaults, porque UserDefaults se puede borrar con un comando
// de Terminal sin que el usuario se dé cuenta.

import Foundation

// FocusStore implementa SessionStoring — el Dominio lo conoce solo por ese protocolo.
class FocusStore: SessionStoring {

    // Carpeta base donde viven todos los archivos de la app
    private static let appSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("FocusMode")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private static let sessionURL       = appSupport.appendingPathComponent("session.json")
    private static let listsURL         = appSupport.appendingPathComponent("lists.json")
    private static let permanentBlockURL = appSupport.appendingPathComponent("permanent_block.json")

    // MARK: - Sesión

    // Guarda la sesión activa en disco
    func saveSession(_ session: FocusSession) throws {
        let data = try JSONEncoder().encode(session)
        try data.write(to: FocusStore.sessionURL, options: .atomic)
    }

    // Lee la sesión guardada. Devuelve nil si no hay ninguna.
    func loadSession() -> FocusSession? {
        guard let data = try? Data(contentsOf: FocusStore.sessionURL) else { return nil }
        return try? JSONDecoder().decode(FocusSession.self, from: data)
    }

    // Borra la sesión del disco (se llama cuando el timer expira)
    func clearSession() {
        try? FileManager.default.removeItem(at: FocusStore.sessionURL)
    }

    // MARK: - Bloqueo permanente

    // Estructura interna para serializar los dos valores juntos en un archivo
    private struct PermanentBlockState: Codable {
        var enabled: Bool
        var snoozedUntil: Date?
    }

    // Guarda si el usuario autorizó el bloqueo permanente y hasta cuándo está pospuesto
    func savePermanentBlock(enabled: Bool, snoozedUntil: Date?) throws {
        let state = PermanentBlockState(enabled: enabled, snoozedUntil: snoozedUntil)
        let data = try JSONEncoder().encode(state)
        try data.write(to: FocusStore.permanentBlockURL, options: .atomic)
    }

    // Lee el estado del bloqueo permanente.
    // Si no existe el archivo (primera vez), devuelve valores por defecto: no activado, sin snooze.
    func loadPermanentBlock() -> (enabled: Bool, snoozedUntil: Date?) {
        guard let data = try? Data(contentsOf: FocusStore.permanentBlockURL),
              let state = try? JSONDecoder().decode(PermanentBlockState.self, from: data)
        else {
            return (enabled: false, snoozedUntil: nil)
        }
        return (enabled: state.enabled, snoozedUntil: state.snoozedUntil)
    }

    // MARK: - Listas

    // Guarda las 4 listas en disco
    func saveLists(_ lists: FocusLists) throws {
        let data = try JSONEncoder().encode(lists)
        try data.write(to: FocusStore.listsURL, options: .atomic)
    }

    // Lee las listas. Si no existe el archivo, devuelve listas vacías.
    func loadLists() -> FocusLists {
        guard let data = try? Data(contentsOf: FocusStore.listsURL) else { return FocusLists() }
        return (try? JSONDecoder().decode(FocusLists.self, from: data)) ?? FocusLists()
    }
}
