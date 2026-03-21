import subprocess
import listas
import tempfile
import os
from datetime import datetime

# Estas son las marcas que FocusMode usa para identificar sus propias líneas en /etc/hosts
# Todo lo que esté entre START y END fue puesto por nosotros — nada más se toca
MARCA_START = "# FocusMode:DEADZONE:START"
MARCA_END = "# FocusMode:DEADZONE:END"
MARCA_VOID_START = "# FocusMode:VOID:START"
MARCA_VOID_END = "# FocusMode:VOID:END"

# Ruta del archivo que controla los bloqueos del sistema
HOSTS = "/etc/hosts"

def escribir_hosts(contenido, mensaje):
    # Guarda el contenido en un archivo temporal
    # No podemos pasarle texto directo a osascript, entonces lo guardamos
    # en un archivo temporal y luego lo copiamos a /etc/hosts con privilegios
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as tmp:
        tmp.write(contenido)
        ruta_tmp = tmp.name

    # osascript ejecuta el comando con la ventana nativa de contraseña de Mac
    # with prompt personaliza el mensaje que ve el usuario en esa ventana
    comando = f'do shell script "cp {ruta_tmp} {HOSTS}" with administrator privileges with prompt "{mensaje}"'
    subprocess.run(["osascript", "-e", comando])

    # Borra el archivo temporal — ya no lo necesitamos
    os.unlink(ruta_tmp)

def esta_activa_deadzone():
    # Abre /etc/hosts y busca si existe nuestra marca de inicio
    # Si existe, significa que el bloqueo está activo
    with open(HOSTS, "r") as f:
        contenido = f.read()
    return MARCA_START in contenido

def activar_deadzone():
    # Si ya está activo, no hacemos nada — evita duplicados
    if esta_activa_deadzone():
        return

    # Carga los sitios de la DeadZone desde config.json
    datos = listas.cargar()
    sitios = datos["deadzone"]

    # Si la lista está vacía, no hay nada que bloquear
    if not sitios:
        return

    # Construye las líneas que vamos a agregar a /etc/hosts
    # Una línea por cada sitio: "0.0.0.0 instagram.com"
    lineas = [MARCA_START]
    for sitio in sitios:
        lineas.append(f"0.0.0.0 {sitio}")
    lineas.append(MARCA_END)

    # Une todas las líneas en un solo bloque de texto
    bloque = "\n" + "\n".join(lineas) + "\n"

    # Lee el contenido actual y le agrega el bloque al final
    with open(HOSTS, "r") as f:
        contenido_actual = f.read()

    # Escribe el archivo completo con el bloque nuevo al final
    # Esto abre la ventana nativa de Mac pidiendo contraseña
    escribir_hosts(contenido_actual + bloque, "FocusMode necesita permiso para activar tu FocusMode y bloquear las distracciones.")

def desactivar_deadzone():
    # Si no está activo, no hay nada que desactivar
    if not esta_activa_deadzone():
        return

    # Lee todo el contenido actual de /etc/hosts
    with open(HOSTS, "r") as f:
        lineas = f.readlines()

    # Filtra las líneas — guarda todo EXCEPTO lo que está entre nuestras marcas
    nuevas_lineas = []
    dentro_del_bloque = False

    for linea in lineas:
        if MARCA_START in linea:
            dentro_del_bloque = True  # entramos al bloque de FocusMode, empezamos a ignorar
        elif MARCA_END in linea:
            dentro_del_bloque = False  # salimos del bloque, volvemos a guardar
        elif not dentro_del_bloque:
            nuevas_lineas.append(linea)  # línea normal del sistema, la guardamos

    # Escribe el archivo limpio — abre la ventana nativa de Mac pidiendo contraseña
    contenido_limpio = "".join(nuevas_lineas)
    escribir_hosts(contenido_limpio, "FocusMode necesita permiso para desactivar el FocusMode.")

def esta_activa_void():
    # Lee void_hasta de config.json
    # Si es None, no hay bloqueo activo
    # Si hay una hora guardada y todavía no llegamos a ella, está activo
    datos = listas.cargar()
    void_hasta = datos.get("void_hasta")
    if void_hasta is None:
        return False
    fin = datetime.fromisoformat(void_hasta)
    return datetime.now() < fin

def void_expiro():
    # Dice si el bloqueo existía pero ya pasó la hora de fin
    # Esto es lo que usa main.py para saber cuándo desactivar automáticamente
    datos = listas.cargar()
    void_hasta = datos.get("void_hasta")
    if void_hasta is None:
        return False
    fin = datetime.fromisoformat(void_hasta)
    return datetime.now() >= fin

def tiempo_restante_void():
    # Devuelve un texto con el tiempo restante en formato "Xd Xh Xm Xs"
    # Devuelve None si no hay bloqueo o ya expiró
    datos = listas.cargar()
    void_hasta = datos.get("void_hasta")
    if void_hasta is None:
        return None
    fin = datetime.fromisoformat(void_hasta)
    diferencia = fin - datetime.now()
    if diferencia.total_seconds() <= 0:
        return None
    # total_seconds() da los segundos totales como número decimal
    # int() quita los decimales
    total = int(diferencia.total_seconds())
    dias = total // 86400
    horas = (total % 86400) // 3600
    minutos = (total % 3600) // 60
    segundos = total % 60
    # Construye el texto solo con las partes que no son cero
    # excepto segundos — esos siempre aparecen
    partes = []
    if dias:
        partes.append(f"{dias}d")
    if horas:
        partes.append(f"{horas}h")
    if minutos:
        partes.append(f"{minutos}m")
    partes.append(f"{segundos}s")
    return " ".join(partes)

def activar_void(hasta=None, duracion=None):
    if hasta is None and duracion is None:
        return
    # Si ya hay un bloqueo void en /etc/hosts, no duplicamos
    with open(HOSTS, "r") as f:
        contenido_actual = f.read()
    if MARCA_VOID_START in contenido_actual:
        return

    # Construye el bloque con los sitios de VoidList
    datos = listas.cargar()
    sitios = datos["void"]
    if not sitios:
        return
    lineas = [MARCA_VOID_START]
    for sitio in sitios:
        lineas.append(f"0.0.0.0 {sitio}")
    lineas.append(MARCA_VOID_END)
    bloque = "\n" + "\n".join(lineas) + "\n"

    # Primero escribimos /etc/hosts — el usuario escribe la clave aquí
    escribir_hosts(contenido_actual + bloque, "FocusMode necesita permiso para activar VoidList.")

    # Verificamos que el bloqueo realmente quedó en /etc/hosts
    # Si el usuario canceló la contraseña, el archivo no cambió — no guardamos nada
    with open(HOSTS, "r") as f:
        resultado = f.read()
    if MARCA_VOID_START not in resultado:
        return

    # DESPUÉS de confirmar que el bloqueo existe, guardamos la hora de fin
    # Si el usuario pasó una duración, calculamos desde ahora (justo después de la clave)
    # Si pasó una hora exacta, la usamos tal cual
    if duracion is not None:
        hasta = datetime.now() + duracion
    datos["void_hasta"] = hasta.isoformat()
    listas.guardar(datos)

def desactivar_void():
    # Filtra las líneas de VoidList fuera de /etc/hosts
    with open(HOSTS, "r") as f:
        lineas = f.readlines()
    nuevas_lineas = []
    dentro_del_bloque = False
    for linea in lineas:
        if MARCA_VOID_START in linea:
            dentro_del_bloque = True
        elif MARCA_VOID_END in linea:
            dentro_del_bloque = False
        elif not dentro_del_bloque:
            nuevas_lineas.append(linea)
    contenido_limpio = "".join(nuevas_lineas)
    escribir_hosts(contenido_limpio, "FocusMode necesita permiso para desactivar VoidList.")

    # Verificamos que el bloqueo realmente se eliminó de /etc/hosts
    # Si el usuario canceló la contraseña, el archivo no cambió — no tocamos config.json
    with open(HOSTS, "r") as f:
        resultado = f.read()
    if MARCA_VOID_START in resultado:
        return

    # Solo si /etc/hosts quedó limpio, borramos void_hasta de config.json
    datos = listas.cargar()
    datos["void_hasta"] = None
    listas.guardar(datos)
