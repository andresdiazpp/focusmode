# TODO — Deuda técnica y decisiones pendientes

Cosas que se dejaron para después con intención. No son bugs, son decisiones conscientes.
Cada entrada dice qué es, por qué se dejó, y dónde está en el código.

---

## 1. Migrar SMJobBless → SMAppService

**Qué falta:** `SMJobBless` está deprecado desde macOS 13. El reemplazo moderno es `SMAppService`.

**Por qué se dejó:** Migrar requiere cambiar la estructura del bundle — el `.plist` del helper debe moverse de `Contents/Library/LaunchServices/` a `Contents/Library/LaunchDaemons/`. Es un cambio de infraestructura, no una línea.

**Dónde:** `Data/System/HelperClient.swift` línea ~52 — `SMJobBless(...)` con comentario explicativo.

**Qué hacer:** Reemplazar `installHelperIfNeeded()` usando `SMAppService.daemon(plistName:).register()`. Mover el plist en el bundle. Verificar que el helper sigue instalándose correctamente.

