// HelperProtocol.swift
// Contrato entre la app principal y el helper.
//
// La app le manda mensajes al helper via XPC.
// El helper solo acepta los mensajes que están definidos aquí.
// Si no está en este protocolo, el helper no lo ejecuta.

import Foundation

// El nombre del servicio XPC — tiene que coincidir en app y helper
let helperMachServiceName = "com.andresdiazpp.focusmode.helper"

@objc protocol HelperProtocol {

    // Escribe los dominios bloqueados en /etc/hosts
    // domains: lista de dominios, ej: ["instagram.com", "twitter.com"]
    func applyHostsBlock(domains: [String], reply: @escaping (Error?) -> Void)

    // Borra las entradas de FocusMode de /etc/hosts
    func removeHostsBlock(reply: @escaping (Error?) -> Void)

    // Cambia el DNS de todas las interfaces activas a CleanBrowsing
    func applyCleanBrowsingDNS(reply: @escaping (Error?) -> Void)

    // Restaura el DNS original (el que tenía el usuario antes)
    func restoreOriginalDNS(reply: @escaping (Error?) -> Void)

    // Escribe dominios de porn de forma permanente en /etc/hosts.
    // Usa marcadores distintos a los de sesión — removeHostsBlock nunca los toca.
    func applyPermanentHostsBlock(domains: [String], reply: @escaping (Error?) -> Void)

    // Bloquea dominios a nivel de red via pf firewall
    // domains: lista de dominios, ej: ["instagram.com", "twitter.com"]
    func applyFirewallBlock(domains: [String], reply: @escaping (Error?) -> Void)

    // Elimina las reglas pf de FocusMode
    func removeFirewallBlock(reply: @escaping (Error?) -> Void)

    // Mensaje de prueba — verifica que el helper responde
    func ping(reply: @escaping (String) -> Void)
}
