import rumps
import bloqueo
from datetime import datetime, timedelta
from AppKit import NSAlert, NSTextField, NSView, NSMakeRect

# Esta es la app. Hereda de rumps.App que hace todo el trabajo de Mac.
class FocusMode(rumps.App):
    def __init__(self):
        super().__init__("🔒 FocusMode", quit_button="Salir")

        # Item que muestra el estado de DeadZone — solo informativo
        self.estado_dead = rumps.MenuItem("DeadZone: Inactiva")
        self.estado_dead.set_callback(None)

        # Item que muestra el estado de VoidList con los minutos restantes
        self.estado_void = rumps.MenuItem("VoidList: Inactiva")
        self.estado_void.set_callback(None)

        # Submenú para activar VoidList — dos opciones dentro
        activar_void_menu = rumps.MenuItem("Activar VoidList")
        activar_void_menu["Por duración"] = rumps.MenuItem("Por duración", callback=self.activar_void_duracion)
        activar_void_menu["Hasta fecha y hora exacta"] = rumps.MenuItem("Hasta fecha y hora exacta", callback=self.activar_void_fecha)

        # Construimos el menú completo
        self.menu = [
            self.estado_dead,
            None,
            rumps.MenuItem("Activar DeadZone", callback=self.activar_deadzone),
            rumps.MenuItem("Desactivar DeadZone", callback=self.desactivar_deadzone),
            None,
            self.estado_void,
            None,
            activar_void_menu,
        ]

        # Al arrancar, revisamos el estado actual de todo
        self.actualizar_estado()

        # Un solo timer cada segundo — revisa expiración y actualiza el display
        self.timer = rumps.Timer(self.revisar_expiracion, 1)
        self.timer.start()

    def actualizar_estado(self, _ =None):
        # Actualiza el texto de DeadZone
        if bloqueo.esta_activa_deadzone():
            self.estado_dead.title = "DeadZone: Activa 🔴"
        else:
            self.estado_dead.title = "DeadZone: Inactiva ⚪"

        # Actualiza el texto de VoidList con el tiempo restante
        tiempo = bloqueo.tiempo_restante_void()
        if tiempo is not None:
            self.estado_void.title = f"VoidList: {tiempo} restantes 🟠"
            self.title = f"🔒 {tiempo} 🔒"
        else:
            self.estado_void.title = "VoidList: Inactiva ⚪"
            self.title = "🔒 FocusMode 🔒"

    def revisar_expiracion(self, _):
        # Corre cada segundo — revisa expiración y actualiza el display
        if bloqueo.void_expiro():
            bloqueo.desactivar_void()
        self.actualizar_estado()

    def activar_deadzone(self, _):
        bloqueo.activar_deadzone()
        self.actualizar_estado()

    def desactivar_deadzone(self, _):
        bloqueo.desactivar_deadzone()
        self.actualizar_estado()

    def activar_void_duracion(self, _):
        alerta = NSAlert.alloc().init()
        alerta.setMessageText_("¿Por cuánto tiempo?")
        alerta.setInformativeText_("Ingresa 0 en los campos que no uses.")
        alerta.addButtonWithTitle_("Activar")
        alerta.addButtonWithTitle_("Cancelar")

        # Contenedor principal — más ancho y con más altura para respirar
        contenedor = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, 300, 80))

        # Ancho de cada columna y alto de cada elemento
        col_ancho = 80
        campo_alto = 28
        label_alto = 18
        espacio_entre = 20  # espacio entre columnas

        # Tres columnas: Días (x=0), Horas (x=100), Minutos (x=200)
        columnas = [
            ("Días",    0),
            ("Horas",   col_ancho + espacio_entre),
            ("Minutos", (col_ancho + espacio_entre) * 2),
        ]

        campos = []
        for nombre, x in columnas:
            # Label encima del campo
            label = NSTextField.alloc().initWithFrame_(
                NSMakeRect(x, 80 - label_alto, col_ancho, label_alto)
            )
            label.setStringValue_(nombre)
            label.setBezeled_(False)
            label.setDrawsBackground_(False)
            label.setEditable_(False)
            label.setSelectable_(False)
            label.setAlignment_(1)  # 1 = centrado
            contenedor.addSubview_(label)

            # Campo editable centrado debajo del label
            campo = NSTextField.alloc().initWithFrame_(
                NSMakeRect(x, 80 - label_alto - campo_alto - 6, col_ancho, campo_alto)
            )
            campo.setStringValue_("0")
            campo.setAlignment_(1)  # texto centrado dentro del campo
            contenedor.addSubview_(campo)
            campos.append(campo)

        campo_dias, campo_horas, campo_minutos = campos

        alerta.setAccessoryView_(contenedor)
        alerta.layout()

        respuesta = alerta.runModal()
        if respuesta != 1000:
            return

        try:
            dias    = int(campo_dias.stringValue())
            horas   = int(campo_horas.stringValue())
            minutos = int(campo_minutos.stringValue())
        except ValueError:
            rumps.alert("Por favor ingresa solo números enteros.")
            return

        if dias == 0 and horas == 0 and minutos == 0:
            rumps.alert("El tiempo debe ser mayor a cero.")
            return

        duracion = timedelta(days=dias, hours=horas, minutes=minutos)
        bloqueo.activar_void(duracion=duracion)
        self.actualizar_estado()

    def activar_void_fecha(self, _):
        ahora = datetime.now()

        alerta = NSAlert.alloc().init()
        alerta.setMessageText_("¿Hasta cuándo?")
        alerta.setInformativeText_("Bloqueo activo hasta la fecha y hora que elijas.")
        alerta.addButtonWithTitle_("Activar")
        alerta.addButtonWithTitle_("Cancelar")

        # Contenedor: 310 de ancho, 60 de alto
        # Y=0 es la parte de ABAJO en macOS — los campos van de abajo hacia arriba
        contenedor = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, 310, 60))

        def hacer_label(texto, x, ancho):
            # Label encima del campo — y=36 (campos están en y=5, tienen 28 de alto → tope en 33, label en 36)
            label = NSTextField.alloc().initWithFrame_(NSMakeRect(x, 36, ancho, 18))
            label.setStringValue_(texto)
            label.setBezeled_(False)
            label.setDrawsBackground_(False)
            label.setEditable_(False)
            label.setSelectable_(False)
            label.setAlignment_(1)
            return label

        def hacer_campo(valor, x, ancho):
            # Campos en la parte de abajo — y=5 para que haya un poco de margen
            campo = NSTextField.alloc().initWithFrame_(NSMakeRect(x, 5, ancho, 28))
            campo.setStringValue_(str(valor))
            campo.setAlignment_(1)
            return campo

        # Cinco columnas: Año (ancho 75), Mes (50), Día (50), separador visual, Hora (50), Min (50)
        # Con 10px de espacio entre cada uno
        contenedor.addSubview_(hacer_label("Año",     0,   75))
        contenedor.addSubview_(hacer_label("Mes",    85,   50))
        contenedor.addSubview_(hacer_label("Día",   145,   50))
        contenedor.addSubview_(hacer_label("Hora",  215,   50))
        contenedor.addSubview_(hacer_label("Min",   275,   35))

        campo_ano    = hacer_campo(ahora.year,   0,   75)
        campo_mes    = hacer_campo(ahora.month,  85,  50)
        campo_dia    = hacer_campo(ahora.day,    145, 50)
        campo_hora   = hacer_campo(ahora.hour,   215, 50)
        campo_minuto = hacer_campo(ahora.minute, 275, 35)

        for c in [campo_ano, campo_mes, campo_dia, campo_hora, campo_minuto]:
            contenedor.addSubview_(c)

        alerta.setAccessoryView_(contenedor)
        alerta.layout()

        respuesta = alerta.runModal()
        if respuesta != 1000:
            return

        try:
            ano     = int(campo_ano.stringValue())
            mes     = int(campo_mes.stringValue())
            dia     = int(campo_dia.stringValue())
            hora    = int(campo_hora.stringValue())
            minuto  = int(campo_minuto.stringValue())
            hasta   = datetime(ano, mes, dia, hora, minuto)
        except ValueError:
            rumps.alert("Fecha u hora inválida. Revisa los valores ingresados.")
            return

        # Verifica que la fecha sea en el futuro
        if hasta <= datetime.now():
            rumps.alert("Esa fecha ya pasó. Elige una hora futura.")
            return

        bloqueo.activar_void(hasta)
        self.actualizar_estado()

# Punto de entrada — cuando corres el archivo, esto arranca la app
if __name__ == "__main__":
    FocusMode().run()
