import rumps
import bloqueo

# Esta es la app. Hereda de rumps.App que hace todo el trabajo de Mac.
class FocusMode(rumps.App):
    def __init__(self):
        super().__init__("🔒 FocusMode")

        # Este MenuItem muestra el estado actual de la DeadZone
        # No tiene callback porque es solo informativo — no hace nada al hacer click
        self.estado = rumps.MenuItem("DeadZone: Inactiva")
        self.estado.set_callback(None)

        # Construimos el menú con todas las opciones
        # None agrega una línea separadora entre grupos
        self.menu = [
            self.estado,
            None,
            rumps.MenuItem("Activar DeadZone", callback=self.activar_deadzone),
            rumps.MenuItem("Desactivar DeadZone", callback=self.desactivar_deadzone),
        ]

        # Al arrancar, revisamos si el bloqueo ya estaba activo
        # (puede que hayas corrido activar_deadzone() desde la terminal antes)
        self.actualizar_estado()

    def actualizar_estado(self):
        # Pregunta a bloqueo.py si la DeadZone está activa
        # y actualiza el texto del MenuItem de estado
        if bloqueo.esta_activa_deadzone():
            self.estado.title = "DeadZone: Activa 🔴"
        else:
            self.estado.title = "DeadZone: Inactiva ⚪"

    def activar_deadzone(self, _):
        # El _ es porque rumps siempre pasa el MenuItem como argumento
        # No lo necesitamos, pero Python exige recibirlo
        bloqueo.activar_deadzone()
        self.actualizar_estado()

    def desactivar_deadzone(self, _):
        bloqueo.desactivar_deadzone()
        self.actualizar_estado()

# Punto de entrada — cuando corres el archivo, esto arranca la app
if __name__ == "__main__":
    FocusMode().run()