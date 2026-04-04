# Changelog

Registro de lo que se construyó en cada paso y por qué se tomaron las decisiones clave.

---

## Paso 7 — HostsManager real + instalación del helper (2026-04-04)

### Qué se construyó
- `HostsManager.swift`: implementación real que delega el bloqueo de hosts al `PrivilegedHelper` via XPC
- `StubHostsManager` eliminado — ya no se usa
- `HelperClient` corregido: retoma la continuation cuando hay error XPC (evitaba un task leak)
- `AppDelegate` corregido: instala el helper al arrancar con `SMJobBless`
- Team ID corregido en los plists de `SMJobBless` para que coincida con el Team ID real de la cuenta

### Decisiones tomadas
- **HostsManager habla XPC, no escribe directamente**: la app no tiene permisos root. La escritura en `/etc/hosts` la hace el helper.
- **Instalación al arrancar**: si el helper no está instalado, `AppDelegate` lo instala en el primer launch. El usuario ve el diálogo de autorización de macOS una sola vez.
- **Continuation siempre se retoma**: si XPC falla, la continuation se completa con error para que el `async/await` no quede colgado.

### Fix de Xcode
- `FocusMode.entitlements` eliminado de la fase "Copy Bundle Resources" — Xcode procesa el archivo de entitlements automáticamente, no debe estar en esa fase.

---

## Paso 6 — XPC Helper base (2026-04-04)

### Qué se construyó
- Target `PrivilegedHelper` en Xcode (Command Line Tool, Swift)
- `HelperProtocol.swift`: contrato XPC entre app y helper
- `HelperXPC.swift`: implementación de las operaciones root (hosts, DNS)
- `HelperClient.swift`: cliente XPC en la app principal
- `HelperSharedTypes.swift`: copia del protocolo para el target de la app
- `Info.plist` manual para ambos targets con claves SMJobBless
- Entitlements para ambos targets

### Decisiones tomadas
- **SMJobBless en vez de SMAppService**: `SMAppService.daemon()` falla con Personal Team (Apple ID gratis). `SMJobBless` es el API clásico que usan apps como SelfControl y funciona sin cuenta de pago.
- **App Sandbox desactivado**: obligatorio para una app que usa un helper privilegiado y escribe en `/etc/hosts`.
- **Info.plist manual**: `SMPrivilegedExecutables` y `SMAuthorizedClients` no se pueden agregar via las build settings automáticas de Xcode — requieren un plist manual.

### Build Phases configuradas
- `PrivilegedHelper` (ejecutable) → `Contents/Library/LaunchServices/`
- `com.andresdiazpp.focusmode.helper.plist` → `Contents/Library/LaunchDaemons/`

---

## Paso 5 — Protocolos del Dominio + SessionManager (2026-04-04)

### Qué se construyó
- 4 protocolos en `Domain/Protocols/`: `SessionStoring`, `HostsManaging`, `DNSManaging`, `AppMonitoring`
- `BlockEngine.swift`: coordina las 3 capas de bloqueo via protocolos
- `SessionManager.swift`: activa sesiones, persiste en disco, maneja el timer de expiración
- Stubs de sistema en `Data/System/` (reemplazados en Pasos 7-10)
- `HomeViewModel` conectado al `SessionManager`

### Decisiones tomadas
- **Protocolos en vez de clases concretas**: `BlockEngine` habla con `HostsManaging`, no con `HostsManager`. Permite cambiar la implementación (ej: reemplazar stub por real) sin tocar `BlockEngine`.
- **`SessionManager` como `@Observable`**: la UI reacciona automáticamente cuando cambia `activeSession`.
- **Timer en `SessionManager`, no en la UI**: la sesión expira aunque la UI no esté visible.
- **Restauración al arrancar**: si la app se cierra con sesión activa, al reabrir retoma el timer.

---

## Paso 4 — Gestión de listas (2026-04-04)

### Qué se construyó
- `BlockListsView.swift`, `AllowListsView.swift`: UI para agregar y quitar items
- `ListsViewModel.swift`: estado de las 4 listas con persistencia automática
- `AppPickerView.swift`: selector de apps instaladas por bundle ID

### Decisiones tomadas
- **Listas bloqueadas durante sesión activa**: no tiene sentido editar la lista mientras se está aplicando.

---

## Paso 3 — UI principal (2026-04-04)

### Qué se construyó
- `HomeView.swift` + `HomeViewModel.swift`: pantalla principal
- `TimerPickerView.swift`: selector por duración o por hora exacta
- `ModePickerView.swift`: selector Block Mode / Allow Mode

### Decisiones tomadas
- **Dos modos de timer**: por duración (2h 30m) o por hora exacta (martes 8:30 AM). Más flexible para el usuario.
- **`ContentView` como wrapper**: `FocusModeApp` decide si mostrar `PermissionsView` o `ContentView`. `ContentView` solo muestra `HomeView`.

---

## Paso 2 — Onboarding de permisos (2026-04-04)

### Qué se construyó
- `PermissionsView.swift`: estado visual de cada permiso + botón que abre Preferencias del Sistema
- `AppDelegate.swift`: verifica permisos al arrancar

### Decisiones tomadas
- **Verificación al arrancar**: si falta un permiso, la app no muestra la UI principal. Evita confusión si el bloqueo no funciona.
- **`#if DEBUG` en `FocusModeApp`**: en desarrollo siempre muestra `ContentView` para no tener que dar permisos cada vez.

---

## Paso 1 — Modelos y persistencia (2026-04-04)

### Qué se construyó
- `SessionMode.swift`: enum `.block` / `.allow`
- `FocusSession.swift`: sesión activa con `mode` y `endsAt`
- `FocusLists.swift`: las 4 listas del usuario
- `FocusModeError.swift`: todos los errores en un lugar
- `FocusStore.swift`: guarda sesión y listas en JSON en Application Support

### Decisiones tomadas
- **`SessionMode` en vez de `FocusMode`**: `FocusMode` conflicta con el nombre del módulo Swift generado por Xcode.
- **JSON en Application Support, no UserDefaults**: UserDefaults se puede borrar con `defaults delete` desde Terminal. Un archivo en Application Support es más difícil de borrar accidentalmente.
- **`isActive` como computed, no guardado**: `var isActive: Bool { Date.now < endsAt }`. Evita inconsistencias entre el estado guardado y la realidad.

---

## Prerrequisitos (2026-04-04)

### Configuración inicial
- Proyecto Xcode: macOS, SwiftUI, Swift
- Bundle ID: `com.andresdiazpp.FocusMode`
- Team: Andres Diaz (Personal Team) — Apple ID gratis
- Repo: github.com/andresdiazpp/focusmode
- `.gitignore`: excluye `.claude/`, `xcuserdata/`, archivos temporales de Xcode

### Decisiones de arquitectura tomadas desde el inicio
- **Distribución directa** (no App Store): el App Store prohíbe `/etc/hosts`, DNS y `pf`
- **XPC Helper**: operaciones root en un proceso separado, instalado con `SMJobBless`
