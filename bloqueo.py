import subprocess
import listas

# Estas son las marcas que FocusMode usa para identificar sus propias líneas en /etc/hosts
# Todo lo que esté entre START y END fue puesto por nosotros — nada más se toca
MARCA_START = "# FocusMode:START"
MARCA_END = "# FocusMode:END"

# Ruta del archivo que controla los bloqueos del sistema
HOSTS = "/etc/hosts"

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

    # Agrega el bloque a /etc/hosts con permiso de administrador
    # subprocess.run ejecuta un comando de terminal desde Python
    # tee -a agrega texto al final de un archivo sin borrar lo que ya había
    subprocess.run(
        ["sudo", "tee", "-a", HOSTS],
        input=bloque.encode(),
        capture_output=True
    )

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

    # Escribe el archivo limpio con permiso de administrador
    contenido_limpio = "".join(nuevas_lineas)
    subprocess.run(
        ["sudo", "tee", HOSTS],
        input=contenido_limpio.encode(),
        capture_output=True
    )
