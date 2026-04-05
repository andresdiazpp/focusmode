// FocusLists.swift
// Las listas que el usuario configura.
// Se guardan en disco y persisten entre sesiones.

import Foundation

struct FocusLists: Codable {
    var blockApps: [String] = []  // bundle IDs, ej: "com.instagram.instagram"
    var blockWebs: [String] = []  // dominios, ej: "instagram.com"
}
