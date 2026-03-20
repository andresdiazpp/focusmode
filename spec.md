# FocusMode — Spec del proyecto

## Qué hace

App para Mac que bloquea sitios web por un tiempo definido. Una vez activada, no se puede deshacer hasta que se acabe el tiempo.

## Funcionalidades

### Listas
- **Lista negra:** sitios web a bloquear
- **Lista blanca:** sitios web permitidos
- Ambas listas se guardan y persisten entre sesiones

### Modos de bloqueo
- **Modo A:** bloquea solo los sitios de la lista negra
- **Modo B:** bloquea todo excepto los sitios de la lista blanca

### Tiempo
- Por duración: "bloquear por 2 horas"
- Por hora exacta: "bloquear hasta las 6pm"

### Comportamiento
- Una vez activado, no se puede deshacer hasta que termine el tiempo
- Si intentas entrar a un sitio bloqueado, no carga
- Mensaje opcional: si está definido, se muestra al intentar entrar. Si no, simplemente no carga.

## Cómo funciona por dentro

Mac tiene un archivo `/etc/hosts` que le dice al sistema a dónde ir cuando pides una dirección web.
focus-block agrega los sitios bloqueados a ese archivo apuntándolos a `0.0.0.0` (una dirección que no existe).
Un proceso en segundo plano protege ese archivo para que no se pueda deshacer manualmente.

## Stack

- Python 3
- Sin dependencias externas por ahora — solo librerías estándar
