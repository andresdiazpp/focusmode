import rumps

# Esta es la app. Hereda de rumps.App que hace todo el trabajo de Mac.
class FocusMode(rumps.App):
    def __init__(self):
        # El primer argumento es el nombre que aparece en el menu bar
        super().__init__("🔒 FocusMode")

# Punto de entrada — cuando corres el archivo, esto arranca la app
if __name__ == "__main__":
    FocusMode().run()
