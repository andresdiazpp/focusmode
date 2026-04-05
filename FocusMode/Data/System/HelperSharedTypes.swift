// HelperSharedTypes.swift
// Tipos que tanto la app principal como el helper necesitan conocer.
//
// La app y el helper son dos procesos separados — no comparten código.
// Por eso este archivo existe en ambos targets con el mismo contenido.
// Si cambias el protocolo aquí, cambiarlo también en PrivilegedHelper/HelperProtocol.swift.

import Foundation

// Nombre del servicio XPC — tiene que ser idéntico en app y helper
let helperMachServiceName = "com.andresdiazpp.focusmode.helper"

@objc protocol HelperProtocol {
    func applyHostsBlock(domains: [String], reply: @escaping (Error?) -> Void)
    func removeHostsBlock(reply: @escaping (Error?) -> Void)
    func applyCleanBrowsingDNS(reply: @escaping (Error?) -> Void)
    func restoreOriginalDNS(reply: @escaping (Error?) -> Void)
    func applyPermanentHostsBlock(domains: [String], reply: @escaping (Error?) -> Void)
    func applyFirewallBlock(domains: [String], reply: @escaping (Error?) -> Void)
    func removeFirewallBlock(reply: @escaping (Error?) -> Void)
    func ping(reply: @escaping (String) -> Void)
}
