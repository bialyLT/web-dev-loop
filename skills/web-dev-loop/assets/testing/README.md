# El stack de testeo — arquitectura modular

El objetivo: **agregar herramientas y dominios de testeo sin romper lo que ya funciona**.
Para eso el stack tiene tres capas que no se mezclan.

```
testing/
├─ registry.json          QUÉ hay en este proyecto (proyecto, gates, testers, adapters)
├─ adapters/*.md          CÓMO se usa cada herramienta (y qué trampas tiene)
└─ ../tools/harness.mjs   QUÉ se ve igual en todos los dominios (check, cleanup, resumen)
```

## Capa 1 — El registro (declarativo)

`testing/registry.json` es la **única fuente de verdad** sobre testers y gates. Ni el
orquestador ni los agentes adivinan: leen el registro.

```jsonc
{
  "project": {
    "name": "mi-app",
    "appUrl": "http://127.0.0.1:3100",
    "db": { "dev": "mi_app_dev", "test": "mi_app_test", "port": 5433 }
  },
  "gates": {
    "typecheck": "npm run typecheck",
    "unit": "npm test",
    "smoke": "npm run smoke -- --reset",
    "build": "npm run build",
    "flows": "powershell -File scripts/flows.ps1"
  },
  "testers": [
    {
      "id": "ui",
      "domain": "ui",
      "agent": "agents/tester-ui.md",
      "capabilities": ["interaccion", "geometria", "accesibilidad", "e2e"],
      "adapters": ["maestro", "cdp"],
      "batteries": "scripts/tester-ui/",
      "regression": "scripts/tester-ui-prior/",
      "budget": { "maxFlows": 30, "maxRuntimeMin": 90 }
    }
  ]
}
```

Campos por tester:

| Campo | Para qué |
|---|---|
| `id` | cómo lo invoca el orquestador |
| `domain` | dominio que cubre (`ui`, `db`, `quality`, `api`, `perf`, `security`) |
| `agent` | archivo con el contrato |
| `capabilities` | qué sabe hacer: el orquestador elige por capacidad, no por intuición |
| `adapters` | qué herramientas usa (deben existir fichas en `adapters/`) |
| `batteries` | dónde vive sus baterías |
| `regression` | dónde viven las baterías de la ronda anterior (se re-corren enteras) |
| `budget` | límites de la ronda (flujos, minutos) para que no seInfle |

## Capa 2 — Los adapters (una ficha por herramienta)

Un adapter documenta una **herramienta**, no un dominio. Su contrato:

- **Cómo se invoca** (comando exacto, variables, precondiciones, cómo se la detiene).
- **Qué puede y qué no puede afirmar** (límites del runner).
- **Las trampas**, con el síntoma exacto para reconocerlas.
- **Cómo se integra** con el harness y cómo se limpia lo que crea.

Fichas incluidas: `maestro.md`, `cdp.md`, `sql.md`, `quality.md`. Agregar una herramienta
nueva = un archivo más + una línea en el `adapters` del tester que la use. **Ningún otro
archivo se toca.**

### Regla de oro de los adapters

> Si dos herramientas pueden afirmar lo mismo, elegí una y dejá la otra como sonda
> auxiliar. Medir dos veces lo mismo con dos runners distintos produce dos verdades y
> cero confianza.

Y la regla que nos costó una ronda:

> **Un runner de UI y su MCP no conviven.** El MCP de Maestro y el CLI de Maestro pelean por
> `~/.maestro/sessions`: el síntoma es un flow que tarda el doble o muere en el primer
> `openLink` con un error que culpa a Chrome. Elegí uno.

## Capa 3 — El harness (lo que todos comparten)

`tools/harness.mjs` es lo que hace que un tester de base de datos y uno de UI produzcan
salidas comparables. API mínima:

```js
import { suite } from "../../tools/harness.mjs";

const t = await suite("db-03-concurrencia", { file: import.meta.url });

t.check("dos inserts en paralelo dejan una fila", filas === 1, `filas=${filas}`);
t.equal("el total cuadra", total, 1500.5);
t.skip("requiere Postgres 18", process.env.PG_MAJOR < 18);
await t.cleanup();   // borra lo que creó, por id, aunque haya fallado
await t.finish();    // imprime el resumen y fija el exit code
```

Contrato de salida (idéntico para todos los dominios):

```
[OK]   dos inserts en paralelo dejan una fila
[FAIL] el total cuadra  →  esperado 1500.50 · obtenido 1500.49
RESULT ok=1 fail=1 suite=db-03-concurrencia file=scripts/tester-db/03-concurrencia.mjs
```

- `ok` = checks que pasaron, `fail` = los que fallaron.
- **Exit code**: 0 si `fail == 0`, 1 si hay fallas. Así un runner puede encadenar.
- **Reporte JSON** en `reports/<suite>.json` (carpeta gitignored) con cada check: nombre,
  estado, detalle y duración.

`tools/run-batteries.mjs` corre varias baterías y **agrega los números**:

```powershell
node tools/run-batteries.mjs --glob "scripts/tester-*/0*.mjs" --out reports/summary.json
```

Salida: una tabla por batería, el total (`ok` / `fail`) y exit code 1 si alguna falla. Con
eso, el informe del tester puede citar **números canónicos** sin que el orquestador sepa
qué midió cada tester.

## Reglas que aplican a todos los testers

1. **Las baterías son durables**: quedan en el repo, se re-corren enteras en cada ronda y
   **no se editan** para hacerlas pasar (si una pasa a ser obsoleta, se agrega otra y la
   vieja queda como regresión).
2. **Limpiar por id**, nunca por texto: los datos sembrados tienen descripciones genéricas.
3. **Nada de credenciales reales** en los fixtures.
4. **Un runner a la vez.**
5. **El repro falla primero**: la batería se ve roja antes del arreglo. Una batería que
   siempre estuvo verde no prueba nada.
6. **Los números van en el informe**, no en la memoria del subagente: el orquestador lee
   el informe.
