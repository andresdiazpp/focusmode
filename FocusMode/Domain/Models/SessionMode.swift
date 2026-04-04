// SessionMode.swift
// Los dos modos de bloqueo que el usuario puede activar.
// Se llama SessionMode y NO FocusMode para evitar conflicto con el nombre de la app.

enum SessionMode: String, Codable {
    case block  // bloquea lo que el usuario pone en sus listas
    case allow  // solo permite lo que el usuario aprueba, bloquea todo lo demás
}
