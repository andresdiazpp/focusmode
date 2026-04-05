// HelperClient.swift
// La app principal usa esto para hablar con el PrivilegedHelper via XPC.
//
// HelperClient abre la conexión, manda el mensaje, y devuelve el resultado.
// Toda la comunicación es async — la app no se congela esperando al helper.

import Foundation
import ServiceManagement  // para SMJobBless (instalar el helper)
import CommonCrypto       // para SHA256 (detección de cambios en el helper)

final class HelperClient {

    // Conexión XPC al helper — se crea al primer uso
    private var connection: NSXPCConnection?

    // MARK: - Instalación del helper

    // Instala el helper como daemon privilegiado via SMJobBless.
    // macOS muestra un diálogo pidiendo la contraseña del administrador.
    // Funciona con Apple ID gratis (Personal Team) — no requiere $99/año.
    func installHelperIfNeeded() throws {
        let installedURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/com.andresdiazpp.focusmode.helper")

        // El helper vive en Contents/Library/LaunchServices/ — no en Contents/MacOS/.
        // forAuxiliaryExecutable busca en MacOS/, así que construimos la ruta a mano.
        let bundledURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/com.andresdiazpp.focusmode.helper")
        guard FileManager.default.fileExists(atPath: bundledURL.path) else {
            log("[HelperClient] Helper no encontrado en el bundle: \(bundledURL.path)")
            return
        }

        // Si el helper está instalado, comparamos el SHA256 de ambos binarios.
        // SHA256 detecta cualquier cambio de contenido — el tamaño puede coincidir
        // aunque el binario sea distinto (dos builds con el mismo número de bytes).
        if FileManager.default.fileExists(atPath: installedURL.path) {
            let installedHash = sha256(of: installedURL)
            let bundledHash   = sha256(of: bundledURL)
            if installedHash != nil && installedHash == bundledHash {
                return  // mismo binario — no hay nada que reinstalar
            }
            // hashes distintos (o no se pudo leer) — reinstalar abajo
            log("[HelperClient] Helper cambió — reinstalando")
        }

        // Crear la autorización con el derecho de instalar helpers privilegiados.
        // Usamos withCString y withUnsafeMutablePointer para que los punteros
        // vivan durante toda la llamada a AuthorizationCreate.
        var authRef: AuthorizationRef?
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let authStatus: OSStatus = kSMRightBlessPrivilegedHelper.withCString { namePtr in
            var item = AuthorizationItem(name: namePtr, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                return AuthorizationCreate(&rights, nil, authFlags, &authRef)
            }
        }
        guard authStatus == errAuthorizationSuccess else {
            throw HelperClientError.authorizationFailed
        }
        defer { if let ref = authRef { AuthorizationFree(ref, []) } }

        // SMJobBless copia el helper a /Library/PrivilegedHelperTools/ y lo registra en launchd.
        // Nota: SMJobBless está deprecado desde macOS 13. La migración a SMAppService
        // requiere cambiar la estructura del bundle (mover el plist a LaunchDaemons/).
        // Se migra en un paso futuro dedicado.
        var cfError: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            "com.andresdiazpp.focusmode.helper" as CFString,
            authRef,
            &cfError
        )

        if !success {
            if let error = cfError?.takeRetainedValue() {
                throw error
            }
            throw HelperClientError.installFailed
        }
    }

    // MARK: - Conexión

    // Devuelve la conexión activa o crea una nueva
    private func getConnection() -> NSXPCConnection {
        if let existing = connection {
            return existing
        }

        let conn = NSXPCConnection(machServiceName: helperMachServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)

        // Si la conexión se cae, la limpiamos para reconectar en el próximo uso
        conn.invalidationHandler = { [weak self] in
            self?.connection = nil
        }
        conn.resume()
        connection = conn
        return conn
    }

    // Devuelve un proxy del helper con un error handler que puede resumir
    // la continuación si la conexión XPC falla en medio de una llamada.
    //
    // Antes de conectar, verifica que el helper esté instalado.
    // Si no está instalado (o el usuario nunca dio la clave), lo instala aquí.
    // Esto hace que CUALQUIER operación futura que use proxy() obtenga este
    // comportamiento automáticamente — sin tener que recordarlo en cada función.
    private func proxy<T>(cont: CheckedContinuation<T, Error>) -> HelperProtocol? {
        log("[DEBUG] HelperClient: proxy() — instalando helper si hace falta...")
        do {
            try installHelperIfNeeded()
        } catch {
            log("[DEBUG] HelperClient: installHelperIfNeeded falló — \(error)")
            cont.resume(throwing: error)
            return nil
        }
        log("[DEBUG] HelperClient: helper listo — abriendo conexión XPC...")

        let conn = getConnection()
        let p = conn.remoteObjectProxyWithErrorHandler { [weak self] error in
            log("[DEBUG] HelperClient: error XPC en remoteObjectProxy — \(error)")
            self?.connection = nil
            cont.resume(throwing: error)
        } as? HelperProtocol

        if p == nil {
            log("[DEBUG] HelperClient: cast a HelperProtocol falló — proxy es nil")
        } else {
            log("[DEBUG] HelperClient: proxy listo — enviando mensaje XPC...")
        }
        return p
    }

    // MARK: - Operaciones

    func ping() async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.ping { message in cont.resume(returning: message) }
        }
    }

    func applyHostsBlock(domains: [String]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.applyHostsBlock(domains: domains) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func removeHostsBlock() async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.removeHostsBlock { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func applyCleanBrowsingDNS() async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.applyCleanBrowsingDNS { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func restoreOriginalDNS() async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.restoreOriginalDNS { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func applyPermanentHostsBlock(domains: [String]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.applyPermanentHostsBlock(domains: domains) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func applyFirewallBlock(domains: [String]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.applyFirewallBlock(domains: domains) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func removeFirewallBlock() async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                // proxy() ya resumió la continuación con el error — solo retornamos
                return
            }
            p.removeFirewallBlock { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    // Calcula el SHA256 de un archivo. Devuelve nil si no se puede leer.
    // SHA256 es un hash — dos archivos con contenido idéntico dan el mismo resultado.
    // Dos archivos distintos (aunque tengan el mismo tamaño) dan resultados diferentes.
    private func sha256(of url: URL) -> Data? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return Data(hash)
    }
}

// Errores propios del cliente XPC — fuera de la clase
enum HelperClientError: Error {
    case connectionFailed       // no se pudo conectar al helper
    case authorizationFailed    // no se pudo crear la autorización
    case installFailed          // SMJobBless falló sin error específico
}
