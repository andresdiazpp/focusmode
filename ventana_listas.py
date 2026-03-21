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
import bloqueo
import rumps

# Variables a nivel de módulo — Python borra objetos que nadie "sostiene"
# Guardamos la ventana y las fuentes de datos aquí para que nunca se borren
_ventana = None
_fuentes = []
_controladores = []

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


class ControladorPestana(NSObject):
    def init(self):
        self = objc.super(ControladorPestana, self).init()
        self.clave = None    # "deadzone", "void", o "energy"
        self.fuente = None   # la FuenteDatos de la tabla de esta pestaña
        self.tabla = None    # la NSTableView para poder redibujarla
        return self

    def agregar_(self, sender):
        from AppKit import NSAlert, NSTextField

        alerta = NSAlert.alloc().init()
        alerta.setMessageText_("Agregar sitio")
        alerta.setInformativeText_("Escribe el dominio exacto. Ejemplo: reddit.com")
        alerta.addButtonWithTitle_("Agregar")
        alerta.addButtonWithTitle_("Cancelar")

        # Campo de texto donde el usuario escribe el dominio
        campo = NSTextField.alloc().initWithFrame_(NSMakeRect(0, 0, 280, 28))
        campo.setStringValue_("")
        alerta.setAccessoryView_(campo)
        alerta.layout()

        NSApp.activateIgnoringOtherApps_(True)
        respuesta = alerta.runModal()

        # 1000 = botón principal (Agregar), cualquier otro = Cancelar
        if respuesta != 1000:
            return

        sitio = campo.stringValue().strip()
        if not sitio:
            return

        # Guardamos el sitio en config.json
        listas.agregar(sitio, self.clave)

        # Si el bloqueo está activo, actualizamos /etc/hosts con el sitio nuevo
        if self.clave == "deadzone":
            bloqueo.actualizar_deadzone()
        elif self.clave == "void":
            bloqueo.actualizar_void()

        # Actualizamos la tabla visualmente con los datos nuevos
        self.fuente.setSitios_(listas.cargar()[self.clave])
        self.tabla.reloadData()

    def editar_(self, sender):
        from AppKit import NSAlert, NSTextField

        # Si el bloqueo está activo, no se puede editar — reduciría el bloqueo
        if (self.clave == "deadzone" and bloqueo.esta_activa_deadzone()) or \
           (self.clave == "void" and bloqueo.esta_activa_void()):
            rumps.alert("Bloqueo activo", "No puedes editar sitios mientras el bloqueo está activo.")
            return

        # selectedRow devuelve -1 si no hay ninguna fila seleccionada
        fila = self.tabla.selectedRow()
        if fila == -1:
            return

        sitio_actual = self.fuente.sitios[fila]

        alerta = NSAlert.alloc().init()
        alerta.setMessageText_("Editar sitio")
        alerta.setInformativeText_("Cambia el dominio y presiona Guardar.")
        alerta.addButtonWithTitle_("Guardar")
        alerta.addButtonWithTitle_("Cancelar")

        # Campo con el valor actual para que el usuario lo edite
        campo = NSTextField.alloc().initWithFrame_(NSMakeRect(0, 0, 280, 28))
        campo.setStringValue_(sitio_actual)
        alerta.setAccessoryView_(campo)
        alerta.layout()

        NSApp.activateIgnoringOtherApps_(True)
        respuesta = alerta.runModal()

        if respuesta != 1000:
            return

        sitio_nuevo = campo.stringValue().strip()
        if not sitio_nuevo or sitio_nuevo == sitio_actual:
            return

        # Borramos el viejo y agregamos el nuevo
        listas.eliminar(sitio_actual, self.clave)
        listas.agregar(sitio_nuevo, self.clave)

        # Actualizamos la tabla visualmente
        self.fuente.setSitios_(listas.cargar()[self.clave])
        self.tabla.reloadData()

    def eliminar_(self, sender):
        # Si el bloqueo está activo, no se puede eliminar — reduciría el bloqueo
        if (self.clave == "deadzone" and bloqueo.esta_activa_deadzone()) or \
           (self.clave == "void" and bloqueo.esta_activa_void()):
            rumps.alert("Bloqueo activo", "No puedes eliminar sitios mientras el bloqueo está activo.")
            return

        # selectedRow devuelve -1 si no hay ninguna fila seleccionada
        fila = self.tabla.selectedRow()
        if fila == -1:
            return

        sitio = self.fuente.sitios[fila]

        # Borramos de config.json
        listas.eliminar(sitio, self.clave)

        # Actualizamos la tabla visualmente
        self.fuente.setSitios_(listas.cargar()[self.clave])
        self.tabla.reloadData()


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

    return scroll, tabla, fuente


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
        scroll, tabla, fuente = hacer_tabla(datos[clave], frame_tabla)
        vista.addSubview_(scroll)

        # Creamos el controlador para esta pestaña
        # Le damos la clave, la fuente y la tabla para que sepa qué manejar
        controlador = ControladorPestana.alloc().init()
        controlador.clave = clave
        controlador.fuente = fuente
        controlador.tabla = tabla
        _controladores.append(controlador)  # guardamos para que Python no lo borre

        # Doble click en la tabla llama a editar: en el controlador
        tabla.setTarget_(controlador)
        tabla.setDoubleAction_("editar:")

        # Tres botones en la parte de abajo — Y=10, altura=35
        for titulo, x, accion in [
            ("+ Agregar",   10,  "agregar:"),
            ("✏️ Editar",   170, "editar:"),
            ("− Eliminar",  330, "eliminar:"),
        ]:
            boton = NSButton.alloc().initWithFrame_(NSMakeRect(x, 10, 140, 35))
            boton.setTitle_(titulo)
            boton.setBezelStyle_(1)
            boton.setTarget_(controlador)
            boton.setAction_(accion)
            vista.addSubview_(boton)

        item.setView_(vista)
        tabs.addTabViewItem_(item)

    ventana.contentView().addSubview_(tabs)
    ventana.center()

    NSApp.activateIgnoringOtherApps_(True)
    ventana.makeKeyAndOrderFront_(None)
