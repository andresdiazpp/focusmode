import json
import os

# Ruta del archivo donde se guardan las listas
# __file__ es la ubicación de este archivo (listas.py)
# os.path.dirname saca solo la carpeta donde vive
# os.path.join une la carpeta con el nombre del archivo
ARCHIVO = os.path.join(os.path.dirname(__file__), "config.json")

def cargar():
    # Si el archivo no existe todavía, devuelve listas vacías
    if not os.path.exists(ARCHIVO):
        return {"energy": [], "void": []}

    # Abre el archivo y lo convierte de texto JSON a un objeto de Python
    with open(ARCHIVO, "r") as f:
        return json.load(f)

def guardar(energy, void):
    # Toma las dos listas y las escribe en config.json
    # indent=2 hace que el archivo sea legible por humanos, no una sola línea
    with open(ARCHIVO, "w") as f:
        json.dump({"energy": energy, "void": void}, f, indent=2)

def agregar(sitio, lista):
    # Carga las listas actuales
    datos = cargar()

    # Verifica que el sitio no esté ya en la lista para no duplicar
    if sitio not in datos[lista]:
        datos[lista].append(sitio)
        guardar(datos["energy"], datos["void"])
