# Changelog

Registro de lo que se construyó en cada paso y por qué se tomaron las decisiones clave.

---

## Paso 8.4 — BlockEngine incluye dominios de la blocklist en cada sesión (2026-04-04)

### Qué se construyó
- `BlockEngine` recibe `BlocklistFetcher` como dependencia inyectada
- En `activate()`, siempre carga el caché local y lo suma a los dominios del usuario antes de escribir en `/etc/hosts`
- `FocusModeApp` crea el `BlocklistFetcher` y lo pasa a `BlockEngine`
- `AppDelegate` llama `refreshIfNeeded()` al arrancar en background — mantiene la lista fresca sin bloquear la UI

### Verificado
- 657,960 dominios descargados y guardados en `Application Support/FocusMode/blocklist_merged.txt`
- `/etc/hosts` muestra entradas `# FocusMode:START` con dominios de la blocklist
- Log: `Block Mode activado — hosts bloqueados: 657961 (porn: 657960, usuario: 1)`

### Decisiones tomadas
- **`loadCached()` en activate, no red**: la descarga ocurre en background al arrancar; `activate()` solo lee lo que ya está en disco — sin latencia ni posibilidad de fallo de red en el momento del bloqueo
- **`Set` para deduplicar al combinar**: si el usuario agregó manualmente un dominio que ya está en la blocklist, no se escribe dos veces en `/etc/hosts`

---

## Paso 8.3 — BlocklistFetcher: refresh semanal (2026-04-04)

### Qué se construyó
- `refreshIfNeeded()`: punto de entrada principal — revisa si pasaron 7 días y decide si descarga o usa caché
- `needsRefresh()`: lee `blocklist_last_updated.txt` y compara con `Date.now`
- `saveLastUpdated()` / `loadLastUpdated()`: guardan y leen la fecha en formato ISO 8601

### Decisiones tomadas
- **ISO 8601 para la fecha**: formato estándar, legible en cualquier editor de texto, no depende de locale

---

## Paso 8.2 — BlocklistFetcher: merge de dos listas y deduplicación (2026-04-04)

### Qué se construyó
- Segunda fuente agregada: Blocklist Project (porn) — `blocklistproject.github.io/Lists/porn.txt`
- `fetchAndMerge()`: descarga ambas fuentes en paralelo (`async let`), guarda cada caché individual, une con `Set` para deduplicar, ordena y guarda `blocklist_merged.txt`
- `loadCached()` ahora lee `blocklist_merged.txt` (el archivo combinado)
- Función privada `download(from:)` extrae la lógica de red para no repetirla

### Decisiones tomadas
- **Descarga en paralelo**: `async let rawA` y `async let rawB` se lanzan juntos — la espera es el máximo de los dos tiempos, no la suma
- **`Set` para deduplicar**: forma más simple de eliminar repetidos entre dos listas; `sorted()` da orden estable para que el archivo sea comparable entre corridas
- **Cachés individuales separadas**: se guardan `blocklist_stevenblack.txt` y `blocklist_blocklistproject.txt` además del merged — permite depurar qué vino de dónde

---

## Paso 8.1 — BlocklistFetcher: descarga y persiste una blocklist (2026-04-04)

### Qué se construyó
- `BlocklistFetcher.swift` en `Data/Persistence/`: descarga la blocklist de StevenBlack (variante solo-porn), parsea el archivo hosts, y guarda los dominios en `Application Support/FocusMode/blocklist_stevenblack.txt`
- `fetchAndPersist()`: método async que descarga, parsea y escribe en disco — devuelve el array de dominios
- `loadCached()`: lee la lista ya guardada en disco sin hacer red
- `parse(_:)`: función pura que extrae dominios de líneas `0.0.0.0 dominio.com`, descartando comentarios y la entrada del propio `0.0.0.0`

### Decisiones tomadas
- **Variante porn de StevenBlack**: la URL apunta a `alternates/porn/hosts`, no a la lista completa — así solo se bloquea pornografía, no trackers ni malware que no son el foco de la app
- **Un dominio por línea en caché**: formato simple de texto plano, fácil de leer y de combinar con otras listas en el paso 8.2
- **`parse` es estática y pura**: sin dependencias externas, fácil de testear con cualquier string de input

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
