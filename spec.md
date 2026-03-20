# FocusMode — Spec del proyecto

## Qué hace

App para Mac que bloquea sitios web por un tiempo definido. Una vez activada, no se puede deshacer hasta que se acabe el tiempo.

## Funcionalidades

### Listas
- **Lista negra:** sitios web a bloquear
- **Lista blanca:** sitios web permitidos
- Ambas listas se guardan y persisten entre sesiones

### Listas con nombre propio
- **DeadZone** — sitios siempre bloqueados, sin timer, permanente
- **VoidList** — sitios bloqueados a solicitud con timer
- **EnergyList** — sitios siempre permitidos (para modo solo-permite-estas)

### Modos de bloqueo — orden de construcción

#### 1. DeadZone (construir primero — más simple)
- Sitios bloqueados siempre, sin timer
- Se activa/desactiva manualmente desde el menu bar
- Persiste aunque reinicies el Mac

#### 2. VoidList a solicitud (construir segundo — más complejo)
- Se activa por duración ("bloquear 2 horas") o por hora exacta ("hasta las 6pm")
- Una vez activado, no se puede deshacer hasta que termine el tiempo
- Bloquea los sitios de la VoidList durante ese tiempo

#### 3. Solo EnergyList (construir tercero — más restrictivo)
- Bloquea todo excepto los sitios de la EnergyList
- Se activa a solicitud con timer igual que el modo 2

### Comportamiento general
- Si intentas entrar a un sitio bloqueado, no carga
- Mensaje opcional: si está definido, se muestra al intentar entrar. Si no, simplemente no carga.

## Cómo funciona por dentro

Mac tiene un archivo `/etc/hosts` que le dice al sistema a dónde ir cuando pides una dirección web.
focus-block agrega los sitios bloqueados a ese archivo apuntándolos a `0.0.0.0` (una dirección que no existe).
Un proceso en segundo plano protege ese archivo para que no se pueda deshacer manualmente.

## Stack

- Python 3
- Sin dependencias externas por ahora — solo librerías estándar
