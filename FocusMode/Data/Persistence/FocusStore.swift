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

    private static let sessionURL  = appSupport.appendingPathComponent("session.json")
    private static let listsURL    = appSupport.appendingPathComponent("lists.json")

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
