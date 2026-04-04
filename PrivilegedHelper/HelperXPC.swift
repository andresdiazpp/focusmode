// HelperXPC.swift
// El helper que corre como root.
//
// Este proceso vive separado de la app principal.
// La app le manda mensajes via XPC y el helper los ejecuta con privilegios.
// Cada función aquí puede hacer cosas que la app normal no puede:
// escribir /etc/hosts, cambiar DNS, aplicar reglas de firewall.

import Foundation

// HelperXPC implementa HelperProtocol — cada función del protocolo vive aquí
final class HelperXPC: NSObject, HelperProtocol {

    // MARK: - Ping (prueba de conexión)

    func ping(reply: @escaping (String) -> Void) {
        reply("PrivilegedHelper activo")
    }

    // MARK: - /etc/hosts

    // Marca que FocusMode usa para saber qué líneas escribió
    private let hostsStartMark = "# FocusMode:START"
    private let hostsEndMark   = "# FocusMode:END"
    private let hostsPath      = "/etc/hosts"

    func applyHostsBlock(domains: [String], reply: @escaping (Error?) -> Void) {
        do {
            var content = try String(contentsOfFile: hostsPath, encoding: .utf8)

            // Si ya hay un bloque de FocusMode, lo borramos primero
            content = removeExistingBlock(from: content)

            // Construimos el bloque nuevo
            // Cada dominio se redirige a 0.0.0.0 — el navegador no puede llegar ahí
            let lines = domains.map { "0.0.0.0 \($0)" }.joined(separator: "\n")
            let block = "\n\(hostsStartMark)\n\(lines)\n\(hostsEndMark)\n"

            content += block
            try content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
            reply(nil)
        } catch {
            reply(error)
        }
    }

    func removeHostsBlock(reply: @escaping (Error?) -> Void) {
        do {
            var content = try String(contentsOfFile: hostsPath, encoding: .utf8)
            content = removeExistingBlock(from: content)
            try content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
            reply(nil)
        } catch {
            reply(error)
        }
    }

    // Borra todo lo que está entre las marcas de FocusMode
    private func removeExistingBlock(from content: String) -> String {
        var result = content
        while let start = result.range(of: "\n\(hostsStartMark)"),
              let end   = result.range(of: "\(hostsEndMark)\n", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return result
    }

    // MARK: - DNS

    // Archivo donde guardamos el DNS original para poder restaurarlo
    private let savedDNSPath = "/Library/Application Support/FocusMode/original_dns.json"

    func applyCleanBrowsingDNS(reply: @escaping (Error?) -> Void) {
        do {
            // Primero guardamos el DNS actual
            try saveCurrentDNS()

            // CleanBrowsing Adult Filter — bloquea adultos y VPNs
            let primaryDNS   = "185.228.168.10"
            let secondaryDNS = "185.228.169.11"

            // Aplicamos el DNS en todas las interfaces de red activas
            let interfaces = getActiveNetworkInterfaces()
            for iface in interfaces {
                try runNetworkSetup(["-setdnsservers", iface, primaryDNS, secondaryDNS])
            }
            reply(nil)
        } catch {
            reply(error)
        }
    }

    func restoreOriginalDNS(reply: @escaping (Error?) -> Void) {
        do {
            // Leemos el DNS que guardamos antes
            let data = try Data(contentsOf: URL(fileURLWithPath: savedDNSPath))
            let saved = try JSONDecoder().decode([String: [String]].self, from: data)

            // Restauramos cada interfaz con su DNS original
            for (iface, servers) in saved {
                if servers.isEmpty {
                    // Si no tenía DNS configurado, lo dejamos en "Empty"
                    try runNetworkSetup(["-setdnsservers", iface, "Empty"])
                } else {
                    try runNetworkSetup(["-setdnsservers", iface] + servers)
                }
            }
            reply(nil)
        } catch {
            reply(error)
        }
    }

    // Lee el DNS actual de cada interfaz y lo guarda en un archivo JSON
    private func saveCurrentDNS() throws {
        let interfaces = getActiveNetworkInterfaces()
        var dns: [String: [String]] = [:]

        for iface in interfaces {
            // networksetup -getdnsservers devuelve los servidores actuales
            let output = try runNetworkSetupOutput(["-getdnsservers", iface])
            // Si dice "There aren't any DNS Servers..." significa que no hay configurado
            let servers = output
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("There aren") }
            dns[iface] = servers
        }

        let folder = URL(fileURLWithPath: savedDNSPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(dns)
        try data.write(to: URL(fileURLWithPath: savedDNSPath))
    }

    // Lista de interfaces de red activas (Wi-Fi, Ethernet, etc.)
    private func getActiveNetworkInterfaces() -> [String] {
        let output = (try? runNetworkSetupOutput(["-listallnetworkservices"])) ?? ""
        return output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("An asterisk") && !$0.hasPrefix("*") }
            .dropFirst() // la primera línea es el encabezado
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // Ejecuta networksetup y descarta el output
    @discardableResult
    private func runNetworkSetup(_ args: [String]) throws -> String {
        return try runNetworkSetupOutput(args)
    }

    // Ejecuta networksetup y devuelve el output como String
    private func runNetworkSetupOutput(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - pf Firewall

    // Ruta del archivo de reglas que FocusMode escribe
    private let pfAnchorPath = "/etc/pf.anchors/focusmode"
    // Nombre del anchor dentro de pf
    private let pfAnchorName = "focusmode"
    // Línea que FocusMode agrega a /etc/pf.conf para cargar sus reglas
    private let pfAnchorLine = "anchor \"focusmode\""
    private let pfLoadLine   = "load anchor \"focusmode\" from \"/etc/pf.anchors/focusmode\""
    private let pfConfPath   = "/etc/pf.conf"

    func applyFirewallBlock(domains: [String], reply: @escaping (Error?) -> Void) {
        do {
            // Resolver las IPs de cada dominio
            // pf trabaja con IPs, no con nombres de dominio
            var ips: [String] = []
            for domain in domains {
                let resolved = resolveDomain(domain)
                ips.append(contentsOf: resolved)
            }

            // Eliminar duplicados — muchos dominios comparten IPs
            let uniqueIPs = Array(Set(ips))

            // Construir las reglas pf
            // "block drop out" = bloquea tráfico saliente hacia esa IP
            // "block drop in"  = bloquea tráfico entrante desde esa IP
            let rules = uniqueIPs.flatMap { ip in
                [
                    "block drop out quick to \(ip)",
                    "block drop in  quick from \(ip)"
                ]
            }.joined(separator: "\n")

            // Escribir el archivo de anchor
            try rules.write(toFile: pfAnchorPath, atomically: true, encoding: .utf8)

            // Asegurarse que pf.conf incluye nuestro anchor
            try injectAnchorIntoPFConf()

            // Activar pf y recargar las reglas
            try runPFCtl(["-e"])                        // activa el firewall
            try runPFCtl(["-f", pfConfPath])            // recarga reglas

            reply(nil)
        } catch {
            reply(error)
        }
    }

    func removeFirewallBlock(reply: @escaping (Error?) -> Void) {
        do {
            // Vaciar el archivo de anchor — sin IPs, pf no bloquea nada
            try "".write(toFile: pfAnchorPath, atomically: true, encoding: .utf8)

            // Recargar pf para que aplique el archivo vacío
            try runPFCtl(["-f", pfConfPath])

            // Eliminar las líneas de FocusMode de pf.conf
            try removeAnchorFromPFConf()

            reply(nil)
        } catch {
            reply(error)
        }
    }

    // Resuelve un dominio a sus IPs via DNS
    // Devuelve lista vacía si el dominio no resuelve (sin errores fatales)
    private func resolveDomain(_ domain: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family   = AF_UNSPEC    // acepta IPv4 e IPv6
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(domain, nil, &hints, &result) == 0, let info = result else {
            return []
        }
        defer { freeaddrinfo(result) }

        var ips: [String] = []
        var ptr: UnsafeMutablePointer<addrinfo>? = info

        while let current = ptr {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            // getnameinfo convierte la estructura de dirección a un string legible
            if getnameinfo(
                current.pointee.ai_addr,
                current.pointee.ai_addrlen,
                &hostname,
                socklen_t(NI_MAXHOST),
                nil, 0,
                NI_NUMERICHOST   // queremos la IP, no el nombre
            ) == 0 {
                let ip = String(cString: hostname)
                // Filtrar IPv6 link-local (fe80::) — pf puede tener problemas con ellas
                if !ip.hasPrefix("fe80") {
                    ips.append(ip)
                }
            }
            ptr = current.pointee.ai_next
        }

        return ips
    }

    // Agrega las líneas del anchor a /etc/pf.conf si no están ya
    private func injectAnchorIntoPFConf() throws {
        var conf = try String(contentsOfFile: pfConfPath, encoding: .utf8)

        // Si ya están las líneas, no hacemos nada
        guard !conf.contains(pfAnchorLine) else { return }

        // Agregamos al final del archivo
        conf += "\n# FocusMode firewall anchor\n\(pfAnchorLine)\n\(pfLoadLine)\n"
        try conf.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
    }

    // Elimina las líneas del anchor de /etc/pf.conf
    private func removeAnchorFromPFConf() throws {
        var conf = try String(contentsOfFile: pfConfPath, encoding: .utf8)

        // Borramos el bloque de comentario y las dos líneas que agregamos
        let lines = conf.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            !line.contains("FocusMode firewall anchor") &&
            !line.contains(pfAnchorLine) &&
            !line.contains(pfLoadLine)
        }
        conf = filtered.joined(separator: "\n")
        try conf.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
    }

    // Ejecuta pfctl con los argumentos dados
    @discardableResult
    private func runPFCtl(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/pfctl")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        try process.run()
        process.waitUntilExit()

        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
