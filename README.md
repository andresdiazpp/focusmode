# FocusMode

App de macOS que bloquea distracciones. En desarrollo activo.

## Qué hace (hasta ahora)

- Pantalla principal con selector de modo (Block / Allow) y timer
- Gestión de listas de bloqueo y permitidos
- Sesión con timer irrevocable — persiste en disco aunque la app se cierre
- PrivilegedHelper: proceso separado que corre como root para operaciones de sistema
- HostsManager real: delega el bloqueo de hosts al helper via XPC
- Helper se instala automáticamente al primer arranque (autorización de macOS una sola vez)
- BlocklistFetcher: descarga StevenBlack y Blocklist Project (porn), las combina sin repetidos, se refresca semanalmente
- Clean Mode activo: 657k+ dominios de porn bloqueados en /etc/hosts en cada sesión

## Arquitectura

```
Presentación  →  UI (SwiftUI)
Dominio       →  lógica pura (SessionManager, BlockEngine)
Datos         →  disco y sistema (FocusStore, stubs de HostsManager/DNSManager/AppMonitor)

PrivilegedHelper  →  proceso root via XPC (SMJobBless)
```

## Permisos necesarios

- **Full Disk Access** — para escribir `/etc/hosts`
- **Accessibility** — para cerrar apps bloqueadas
- **Helper (root)** — para cambiar DNS y aplicar firewall, se pide una vez

## Requisitos

- macOS 15+
- No requiere Apple Developer Account de pago

## Distribución

Fuera del App Store — las operaciones de sistema que usa están prohibidas en el sandbox.

## Estado

Ver [CHANGELOG.md](CHANGELOG.md) para el detalle de cada paso construido.
