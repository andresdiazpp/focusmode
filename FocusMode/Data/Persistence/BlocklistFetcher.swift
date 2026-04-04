// BlocklistFetcher.swift
// Descarga dos blocklists remotas, las parsea, las combina y guarda el resultado en disco.
// Solo descarga si pasaron más de 7 días desde la última vez.
//
// Fuentes:
//   1. StevenBlack porn — formato hosts: "0.0.0.0 dominio.com"
//   2. Blocklist Project porn — mismo formato
//
// El resultado final es la unión de ambas sin repetidos, guardada como un dominio por línea.

import Foundation

final class BlocklistFetcher {

    // MARK: - URLs de las dos fuentes

    // StevenBlack: variante solo porn
    static let stevenBlackURL = URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts")!

    // Blocklist Project: lista de pornografía
    static let blocklistProjectURL = URL(string: "https://blocklistproject.github.io/Lists/porn.txt")!

    // Cuántos días entre descargas
    static let refreshIntervalDays: TimeInterval = 7 * 24 * 60 * 60   // 7 días en segundos

    // MARK: - Rutas en disco

    // Carpeta base de la app en Application Support
    private static let appSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("FocusMode")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    // Caché de cada fuente por separado
    static let stevenBlackCacheURL      = appSupport.appendingPathComponent("blocklist_stevenblack.txt")
    static let blocklistProjectCacheURL = appSupport.appendingPathComponent("blocklist_blocklistproject.txt")

    // Archivo merged: unión de las dos listas, sin repetidos
    static let mergedCacheURL = appSupport.appendingPathComponent("blocklist_merged.txt")

    // Archivo que guarda cuándo fue la última descarga exitosa (timestamp ISO 8601)
    static let lastUpdatedURL = appSupport.appendingPathComponent("blocklist_last_updated.txt")

    // MARK: - Refresh semanal

    // Punto de entrada principal.
    // Si el caché tiene menos de 7 días → devuelve los dominios guardados sin tocar la red.
    // Si pasaron 7 días (o nunca se descargó) → descarga, combina y guarda.
    @discardableResult
    func refreshIfNeeded() async throws -> [String] {
        if needsRefresh() {
            let domains = try await fetchAndMerge()
            saveLastUpdated()
            return domains
        } else {
            return loadCached()
        }
    }

    // Devuelve true si nunca se descargó o si pasaron más de 7 días.
    func needsRefresh() -> Bool {
        guard let lastDate = loadLastUpdated() else { return true }
        return Date().timeIntervalSince(lastDate) > Self.refreshIntervalDays
    }

    // MARK: - Fetch y merge

    // Descarga ambas listas en paralelo, las combina y guarda el resultado.
    // Devuelve el array de dominios resultante (sin repetidos, ordenado).
    @discardableResult
    func fetchAndMerge() async throws -> [String] {
        // Descarga las dos fuentes al mismo tiempo (async let = paralelo)
        async let rawA = download(from: Self.stevenBlackURL)
        async let rawB = download(from: Self.blocklistProjectURL)

        // Espera a que ambas terminen
        let (textA, textB) = try await (rawA, rawB)

        // Parsea cada una
        let domainsA = Self.parse(textA)
        let domainsB = Self.parse(textB)

        // Guarda cada caché individual
        try domainsA.joined(separator: "\n").write(to: Self.stevenBlackCacheURL,      atomically: true, encoding: .utf8)
        try domainsB.joined(separator: "\n").write(to: Self.blocklistProjectCacheURL, atomically: true, encoding: .utf8)

        // Une las dos listas: Set elimina repetidos, sorted() da orden estable
        let merged = Array(Set(domainsA + domainsB)).sorted()

        // Guarda la lista combinada
        try merged.joined(separator: "\n").write(to: Self.mergedCacheURL, atomically: true, encoding: .utf8)

        return merged
    }

    // Lee la lista merged guardada en disco.
    // Devuelve array vacío si el archivo no existe todavía.
    func loadCached() -> [String] {
        guard let content = try? String(contentsOf: Self.mergedCacheURL, encoding: .utf8) else {
            return []
        }
        return content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    // MARK: - Fecha de última actualización

    // Guarda la fecha actual como timestamp en disco.
    private func saveLastUpdated() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try? timestamp.write(to: Self.lastUpdatedURL, atomically: true, encoding: .utf8)
    }

    // Lee la fecha guardada. Devuelve nil si el archivo no existe o no se puede parsear.
    private func loadLastUpdated() -> Date? {
        guard let raw = try? String(contentsOf: Self.lastUpdatedURL, encoding: .utf8) else { return nil }
        return ISO8601DateFormatter().date(from: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Descarga

    // Descarga una URL y devuelve el texto crudo.
    private func download(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return text
    }

    // MARK: - Parsing

    // Recibe el texto crudo del archivo hosts y devuelve solo los dominios.
    // Regla: línea válida empieza con "0.0.0.0 " seguido del dominio.
    // Se descartan: comentarios (#), la línea "0.0.0.0 0.0.0.0" y dominios vacíos.
    static func parse(_ raw: String) -> [String] {
        var domains: [String] = []

        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Ignorar comentarios y líneas que no empiezan con "0.0.0.0 "
            guard trimmed.hasPrefix("0.0.0.0 ") else { continue }

            // El dominio es todo lo que viene después de "0.0.0.0 "
            // Se descarta cualquier comentario inline (texto después de #)
            let afterPrefix = trimmed.dropFirst("0.0.0.0 ".count)
            let domainPart  = afterPrefix.split(separator: "#").first ?? afterPrefix[...]
            let domain      = domainPart.trimmingCharacters(in: .whitespaces)

            // Descartar "0.0.0.0" a sí mismo y cadenas vacías
            guard !domain.isEmpty, domain != "0.0.0.0" else { continue }

            domains.append(domain)
        }

        return domains
    }
}
