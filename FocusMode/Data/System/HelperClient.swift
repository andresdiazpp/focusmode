// HelperClient.swift
// La app principal usa esto para hablar con el PrivilegedHelper via XPC.
//
// HelperClient abre la conexión, manda el mensaje, y devuelve el resultado.
// Toda la comunicación es async — la app no se congela esperando al helper.

import Foundation
import ServiceManagement  // para SMAppService (instalar el helper)

final class HelperClient {

    // Conexión XPC al helper — se crea al primer uso
    private var connection: NSXPCConnection?

    // MARK: - Instalación del helper

    // Instala el helper como daemon privilegiado via SMAppService.
    // macOS muestra un diálogo pidiendo aprobación del usuario (System Settings).
    // No necesita AuthorizationRef manual — SMAppService lo maneja solo.
    func installHelperIfNeeded() throws {
        let service = SMAppService.daemon(plistName: "com.andresdiazpp.focusmode.helper.plist")

        switch service.status {
        case .enabled:
            return  // ya está registrado y activo — no hay nada que hacer
        case .requiresApproval:
            // El usuario necesita aprobarlo en System Settings > Login Items
            throw HelperClientError.requiresApproval
        case .notRegistered, .notFound:
            break  // hay que registrar
        @unknown default:
            break
        }

        log("[HelperClient] Registrando helper con SMAppService...")
        do {
            try service.register()
            log("[HelperClient] Helper registrado correctamente")
        } catch {
            log("[HelperClient] register() falló — \(error)")
            throw error
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

}

// Errores propios del cliente XPC — fuera de la clase
enum HelperClientError: Error {
    case connectionFailed       // no se pudo conectar al helper
    case requiresApproval       // el usuario debe aprobar el helper en System Settings
    case installFailed          // register() falló sin error específico
}
