// Log.swift
// Helper de logging con timestamp.
// Reemplaza print() en todo el proyecto.
//
// Uso: log("mensaje")
// Output: [08:43:12.345] mensaje

import Foundation

private let _logFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

func log(_ message: String) {
    let ts = _logFormatter.string(from: Date())
    print("[\(ts)] \(message)")
}
