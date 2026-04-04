// FocusModeError.swift
// Todos los errores posibles de la app en un solo lugar.
// Así cualquier desarrollador sabe de un vistazo qué puede fallar.

enum FocusModeError: Error {
    case licenseRequired        // el usuario intentó usar Block/Allow Mode sin licencia
    case helperNotInstalled     // el XPC Helper no está instalado
    case permissionDenied       // falta un permiso del sistema
    case blocklistDownloadFailed // no se pudo descargar la lista de dominios adultos
    case hostsWriteFailed       // no se pudo escribir /etc/hosts
    case sessionSaveFailed      // no se pudo guardar la sesión en disco
    case sessionLoadFailed      // no se pudo leer la sesión de disco
}
