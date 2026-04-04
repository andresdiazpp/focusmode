// HelperClient.swift
// La app principal usa esto para hablar con el PrivilegedHelper via XPC.
//
// HelperClient abre la conexión, manda el mensaje, y devuelve el resultado.
// Toda la comunicación es async — la app no se congela esperando al helper.

import Foundation
import ServiceManagement  // para SMJobBless (instalar el helper)

final class HelperClient {

    // Conexión XPC al helper — se crea al primer uso
    private var connection: NSXPCConnection?

    // MARK: - Instalación del helper

    // Instala el helper como daemon privilegiado via SMJobBless.
    // macOS muestra un diálogo pidiendo la contraseña del administrador.
    // Funciona con Apple ID gratis (Personal Team) — no requiere $99/año.
    func installHelperIfNeeded() throws {
        // Primero verificamos si el helper ya está instalado y actualizado
        let helperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/com.andresdiazpp.focusmode.helper")
        if FileManager.default.fileExists(atPath: helperURL.path) {
            // Ya instalado — verificar que la versión coincide con la del bundle
            // (por ahora asumimos que está actualizado)
            return
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
    // Cada método pasa su propio cont para que el error no quede colgado.
    private func proxy<T>(cont: CheckedContinuation<T, Error>) -> HelperProtocol? {
        let conn = getConnection()
        return conn.remoteObjectProxyWithErrorHandler { [weak self] error in
            print("[HelperClient] Error XPC: \(error)")
            self?.connection = nil
            cont.resume(throwing: error)
        } as? HelperProtocol
    }

    // MARK: - Operaciones

    func ping() async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                cont.resume(throwing: HelperClientError.connectionFailed)
                return
            }
            p.ping { message in cont.resume(returning: message) }
        }
    }

    func applyHostsBlock(domains: [String]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                cont.resume(throwing: HelperClientError.connectionFailed)
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
                cont.resume(throwing: HelperClientError.connectionFailed)
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
                cont.resume(throwing: HelperClientError.connectionFailed)
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
                cont.resume(throwing: HelperClientError.connectionFailed)
                return
            }
            p.restoreOriginalDNS { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    func applyFirewallBlock(domains: [String]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            guard let p = proxy(cont: cont) else {
                cont.resume(throwing: HelperClientError.connectionFailed)
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
                cont.resume(throwing: HelperClientError.connectionFailed)
                return
            }
            p.removeFirewallBlock { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }
}

// Errores propios del cliente XPC
enum HelperClientError: Error {
    case connectionFailed       // no se pudo conectar al helper
    case authorizationFailed    // no se pudo crear la autorización
    case installFailed          // SMJobBless falló sin error específico
}
