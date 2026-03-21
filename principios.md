# Principios de programación — aprendidos construyendo FocusMode

## 1. Responsabilidad única
Cada función hace una sola cosa. Si una función hace dos cosas, divídela en dos.

**Por qué:** si algo falla, sabes exactamente dónde buscar. Si una función hace cinco cosas y falla, no sabes cuál de las cinco es el problema.

**Ejemplo en FocusMode:** `activar_deadzone`, `desactivar_deadzone` y `esta_activa_deadzone` son tres funciones separadas, no una sola.

---

## 2. DRY — Don't Repeat Yourself
Si escribes la misma lógica en dos lugares, centralízala en una función.

**Por qué:** cuando algo cambia, solo lo cambias en un lugar. Si está repetido, tienes que recordar cambiarlo en todos lados — y si se te olvida uno, tienes un bug.

**Ejemplo en FocusMode:** en vez de usar `subprocess.run` con `sudo` en dos funciones distintas, creamos `escribir_hosts()` y las dos funciones la llaman.

---

## 3. Prueba cada pieza sola antes de conectarla
Antes de conectar todo, prueba cada archivo o función por separado.

**Por qué:** si conectas todo y algo falla, no sabes qué parte está rota. Si pruebas cada pieza sola, sabes exactamente dónde está el problema.

**Ejemplo en FocusMode:** probamos `listas.py` solo antes de conectarlo a `main.py`.

---

## 4. Un cambio a la vez
Si hay varios problemas, ataca uno. Verifícalo. Luego el siguiente.

**Por qué:** cambiar todo junto es la causa número uno de "no sé qué lo rompió."

---

## 5. Define qué debe pasar antes de cambiar algo
Antes de tocar código, escribe en una oración qué esperas que ocurra.

**Por qué:** sin saber el resultado esperado, no puedes saber si algo funcionó o no.
