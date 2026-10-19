# Adapter: CDP (sondas directas al navegador)

## Qué es

Conducción del Chromium a bajo nivel por el **Chrome DevTools Protocol** (WebSocket al
endpoint de depuración). Sirve para lo que el driver de flows no puede: medir el **punto
de toque real**, mandar **combinaciones de teclas**, medir tiempos de red y setear un input
de archivo.

## Cómo se invoca

1. Arrancá Chromium con el puerto de depuración abierto:

```powershell
chrome.exe --remote-debugging-port=9222 --user-data-dir=<perfil temporal> --window-size=1019,557 about:blank
```

2. En Node, conectate al WebSocket del target (`http://127.0.0.1:9222/json`) y usá los
   dominios: `Input.dispatchMouseEvent`, `Input.dispatchKeyEvent`, `Runtime.evaluate`,
   `DOM.setFileInputFiles`, `Page.navigate`, `Network.*`.

Si tu proyecto ya tiene un cliente CDP propio, reusalo: uno que
resuelve la conexión, el target y el reintento. Reusalo: no reescribas el cliente.

## Qué puede y qué no puede afirmar

| Puede | No puede |
|---|---|
| Mandar `Ctrl+K`, `Shift+Tab`, Escape real | Ver "lo que ve una persona" (eso es el flow) |
| Medir el **punto de toque** de un control (`elementFromPoint`) | Ver estilos computados si el elemento está en otro proceso |
| Medir tiempos (Performance/Resource Timing) | Sustituir la verificación de negocio |
| Setear un `<input type=file>` | Ver lo que el usuario ve en un device real |

## Trampas

| Síntoma | Causa | Qué hacer |
|---|---|---|
| El primer clic "no hace nada" (ni foco ni reacción) | **Ventana sorda**: la página todavía no hidrató | Esperá el marcador de hidratación y reintentá **contando el reintento como interacción** |
| El rectángulo dice que el control está visible, pero el tap no llega | Una **capa fija** (pie sticky, toast, overlay) está encima | Medí con `elementFromPoint` en el punto del tap; el bug real es del **punto de toque** |
| El toast se "come" el click del botón de abajo | El overlay no tiene `pointer-events-none` | Verificalo con `elementFromPoint` |
| La geometría difiere entre corridas | Cambió el **viewport** | Fijá el tamaño de ventana y no lo calcules |
| El combo de teclas no llega a la app | El browser lo intercepta | Dispatch de `keyDown`/`keyUp` con modificadores y `preventDefault` |

## Reglas

- **La geometría se juzga por el punto de toque**, nunca por visibilidad. Un tap que cae
  bajo una banda produce un COMPLETED sin error: se pierde el dato en silencio.
- Medí **cada estado** del form: reposo y con ayudas abiertas. Un desplegable abierto
  empuja el layout.
- Una sonda CDP es **una afirmación por archivo**: si hace 50 cosas, cuando falla una no
  sabés cuál.
- Contá **cuántas interacciones** costaste (incluidos reintentos) y el **tiempo hasta el
  resultado en pantalla**: esos son los números del criterio de UX.
- La sonda es una **sonda**: no la conviertas en el criterio de aceptación de negocio.

## Limpieza

Las sondas no dejan datos si no los crean. Si crean, se limpian por **id**.
