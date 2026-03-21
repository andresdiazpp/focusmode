import objc
from AppKit import (
    NSWindow, NSBackingStoreBuffered,
    NSWindowStyleMaskTitled,
    NSWindowStyleMaskClosable,
    NSWindowStyleMaskMiniaturizable,
    NSTabView, NSTabViewItem,
    NSView, NSScrollView, NSTableView, NSTableColumn,
    NSButton, NSObject,
    NSMakeRect, NSApp
)
import listas

# Variables a nivel de módulo — Python borra objetos que nadie "sostiene"
# Guardamos la ventana y las fuentes de datos aquí para que nunca se borren
_ventana = None
_fuentes = []

# FuenteDatos le dice a NSTableView cuántas filas hay y qué texto mostrar en cada una.
# NSTableView no guarda datos — siempre le pregunta a su fuente de datos.
class FuenteDatos(NSObject):
    def init(self):
        # En NSObject el método de inicialización se llama init, no __init__
        self = objc.super(FuenteDatos, self).init()
        self.sitios = []
        return self

    def setSitios_(self, sitios):
        self.sitios = sitios

    def numberOfRowsInTableView_(self, tabla):
        # Mac pregunta: ¿cuántas filas necesitas?
        return len(self.sitios)

    def tableView_objectValueForTableColumn_row_(self, tabla, columna, fila):
        # Mac pregunta: ¿qué texto va en esta fila?
        return self.sitios[fila]


def hacer_tabla(sitios, frame_tabla):
    global _fuentes
    # NSScrollView — el contenedor con scroll que envuelve la tabla
    scroll = NSScrollView.alloc().initWithFrame_(frame_tabla)
    scroll.setHasVerticalScroller_(True)  # activa la barra de scroll vertical
    scroll.setAutohidesScrollers_(True)   # la barra se oculta cuando no hace falta

    # NSTableView — la tabla en sí
    tabla = NSTableView.alloc().initWithFrame_(frame_tabla)

    # NSTableColumn — una columna dentro de la tabla
    # Le damos un identificador y un ancho
    columna = NSTableColumn.alloc().initWithIdentifier_("sitio")
    columna.setWidth_(frame_tabla.size.width)
    columna.headerCell().setStringValue_("Sitio")
    tabla.addTableColumn_(columna)

    # Creamos la fuente de datos con el patrón de NSObject: alloc().init()
    # y luego le pasamos los sitios por separado
    fuente = FuenteDatos.alloc().init()
    fuente.setSitios_(sitios)
    tabla.setDataSource_(fuente)
    _fuentes.append(fuente)  # guardamos la fuente para que Python no la borre

    # Metemos la tabla dentro del scroll
    scroll.setDocumentView_(tabla)

    return scroll, tabla


def abrir():
    global _ventana
    frame = NSMakeRect(0, 0, 500, 400)

    estilo = (
        NSWindowStyleMaskTitled |
        NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable
    )

    _ventana = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
        frame, estilo, NSBackingStoreBuffered, False
    )
    ventana = _ventana
    ventana.setTitle_("FocusMode — Gestionar listas")

    tabs = NSTabView.alloc().initWithFrame_(frame)

    # Cargamos las tres listas desde config.json
    datos = listas.cargar()

    # Para cada pestaña, creamos la vista con su tabla de sitios
    for nombre, clave in [("DeadZone", "deadzone"), ("VoidList", "void"), ("EnergyList", "energy")]:
        item = NSTabViewItem.alloc().initWithIdentifier_(nombre)
        item.setLabel_(nombre)

        vista = NSView.alloc().initWithFrame_(frame)

        # La tabla ocupa el espacio entre los botones (abajo) y el tope de la pestaña
        frame_tabla = NSMakeRect(10, 55, 470, 285)
        scroll, tabla = hacer_tabla(datos[clave], frame_tabla)
        vista.addSubview_(scroll)

        # Tres botones en la parte de abajo — Y=10, altura=35
        # X va de izquierda a derecha: Agregar (0), Editar (160), Eliminar (320)
        for titulo, x in [("+ Agregar", 10), ("✏️ Editar", 170), ("− Eliminar", 330)]:
            boton = NSButton.alloc().initWithFrame_(NSMakeRect(x, 10, 140, 35))
            boton.setTitle_(titulo)
            boton.setBezelStyle_(1)  # 1 = estilo redondeado estándar de Mac
            vista.addSubview_(boton)

        item.setView_(vista)
        tabs.addTabViewItem_(item)

    ventana.contentView().addSubview_(tabs)
    ventana.center()

    NSApp.activateIgnoringOtherApps_(True)
    ventana.makeKeyAndOrderFront_(None)
