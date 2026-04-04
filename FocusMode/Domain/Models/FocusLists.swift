// FocusLists.swift
// Las 4 listas que el usuario configura.
// Se guardan en disco y persisten entre sesiones.

import Foundation

struct FocusLists: Codable {
    // Block Mode: el usuario dice qué bloquear
    var blockApps: [String] = []  // bundle IDs, ej: "com.instagram.instagram"
    var blockWebs: [String] = []  // dominios, ej: "instagram.com"

    // Allow Mode: el usuario dice qué puede funcionar, todo lo demás se bloquea
    var allowApps: [String] = []
    var allowWebs: [String] = []
}
