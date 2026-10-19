# Adapter: Maestro (flows en un navegador real)

## Qué es

Runner de UI end-to-end: escribe flows YAML, abre un Chromium real y ejecuta pasos
(tap, texto, assert). Es la capa que verifica **números en pantalla**, no "que la pantalla
cargue".

## Cómo se invoca

Nunca `maestro.bat` directo: usá un wrapper del proyecto que fije la URL, la semilla y el
lock. Patrón típico (`scripts/flows.ps1`):

```powershell
powershell -File scripts/flows.ps1                    # siembra + todos los flows
powershell -File scripts/flows.ps1 -Flow 04b          # un flow puntual
powershell -File scripts/flows.ps1 -Flow 04b -NoSeed  # sin reseed (encadenado)
```

- El **seed** (smoke) arma el escenario: sin él, los flows verifican contra una base
  vacía y fallan por el motivo equivocado.
- La app tiene que estar **corriendo** (build de producción) en `http://127.0.0.1:<port>`.
- Resultado por flow: PASS/FAIL + **evidencia en `~/.maestro/tests/<timestamp>/`** (capturas
  por paso). Guardá la ruta del directorio: es la prueba.

## Qué puede y qué no puede afirmar

| Puede | No puede |
|---|---|
| Ver números y textos en pantalla | Emitir combinaciones de teclas (`pressKey` sólo ENTER y BACKSPACE) |
| Verificar flows netos cero (guardar y deshacer) | Tocar un elemento recortado por un contenedor con scroll |
| Detectar diálogos nativos (y morirse) | Medir el punto de toque exacto (para eso, sondas CDP) |
| Correr la app en un Chromium real | Correr dos flows en paralelo |

## Trampas (síntoma → causa)

| Síntoma | Causa | Qué hacer |
|---|---|---|
| El flow tarda el doble o muere en el primer `openLink` | Otro Maestro vivo (MCP o CLI) peleando el lock de `~/.maestro/sessions` | Matar el otro. **MCP y CLI no conviven** |
| `DevToolsActivePort file doesn't exist` | Dos runners en paralelo o RAM baja | Un runner a la vez;matá el chrome zombie |
| El assert no matchea aunque el número esté bien | Maestro compara contra el **texto completo** del elemento | Anclá por `id` o usá regex parcial |
| `assertNotVisible` pasa | Lo que querías esconder quedó **fuera de pantalla** | Verificá que esté tapado, no escondido |
| El elemento "no existe" | Está **recortado** por un contenedor con scroll | `scrollUntilVisible` al DATO (no al título) |
| El select elige la opción wrong | Las `<option>` se tocan por **índice** y otro select puede robar el tap | Elegí por índice con cuidado / usar id |
| El submit no dispara | El `type="date"` quedó en `badInput` tras un backspace | Volvé a escribir la fecha |
| Flow que funciona solo y falla en la suite | **La posición es parte del contrato**: hereda el estado de los anteriores | Corrélo pegado al seed o con marcadores únicos |
| El assert de "hoy" falla después de la suite | Los flows cargan fixtures de hoy por diseño | Medí contra una línea base, no contra el vacío |
| El campo de fecha quedó mal en un día nuevo | Fecha "hoy" literal | Calculala; anotá límites de calendario por flow |

## Reglas de los flows

- **Neto cero** cuando el flow crea datos: guardá y des-hacé, o borrá lo que creaste.
- `127.0.0.1`, nunca `localhost`.
- Nada de diálogos nativos en la app:Confirmá inline.
- Selectores por `id` estable, no por texto ("Total.*" pega en el título de fondo).
- Un flow nuevo va en `flows/` con prefijo numérico que indique su **posición** en la
  cadena, y su fila en `flows/README.md` con qué verifica y su límite de calendario.
- La suite completa se corre **una vez** al final de la ronda, no en cada iteración.

## Limpieza

Maestro no deja datos: el flujo es el que deshace. Si un flow dejó filas, se limpian por
**id** (el smoke tiene el helper de borrado).
