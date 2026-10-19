# web-dev-loop

**Una forma de trabajar con agentes de IA en proyectos web** — del pedido al roadmap, del
roadmap a las fases, de la fase al commit verificado. Portable: es un paquete de archivos
que se instala en cualquier máquina con [OpenCode](https://opencode.ai).

Lo que trae:

- 📘 **Una skill global** (`web-dev-loop`) que se anuncia sola cuando el pedido encaja:
  roadmap, propuesta de trabajo, planificación de una fase, elección de testers.
- 🤖 **Cinco agentes nativos** con permisos reales: `dev`, `tester-ui`, `tester-db`,
  `tester-quality`, `security-auditor`. Ni el dev ni los testers pueden commitear; el
  auditor además no puede editar.
- 🧪 **Un stack de testeo modular**: un *registry* declarativo, un *adapter* por
  herramienta y un *harness* común, para que sumar dominios o herramientas sea agregar
  archivos, no reescribir el contrato.

---

## Instalación

### Windows (PowerShell)

```powershell
git clone https://github.com/bialyLT/web-dev-loop.git
cd web-dev-loop
powershell -File install.ps1
```

### macOS / Linux

```bash
git clone https://github.com/bialyLT/web-dev-loop.git
cd web-dev-loop
chmod +x install.sh && ./install.sh
```

Los instaladores copian la skill a `~/.config/opencode/skills/web-dev-loop/` y los agentes
a `~/.config/opencode/agents/`. Para desinstalar, borrá esas dos rutas.

> La skill queda disponible en **todos** tus proyectos. Un proyecto puede pisarla creando
> `.opencode/skills/web-dev-loop/` (la configuración de proyecto tiene más precedencia).

### MCPs (opcional, manual)

La skill no necesita MCPs para funcionar, pero rinde más con documentación al día y
memoria persistente. Pegá esto en tu `~/.config/opencode/opencode.json`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "context7": { "type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true },
      "engram": {
        "type": "local",
        "command": ["<ruta-a-engram>", "mcp", "--tools=agent"],
        "enabled": true
      }
    }
  }
}
```

> El MCP de Maestro queda **fuera** a propósito: pelea con el CLI de Maestro por el lock de
> `~/.maestro/sessions`. Usá uno o el otro, nunca los dos.

---

## Cómo se usa

En cualquier proyecto nuevo, pedile un roadmap:

> "Armame un roadmap para <tu meta>"

La skill encadena:

```
0.1  clasifica el pedido (roadmap con meta | propuesta de tarea)
0.2  inventaría las skills y MCPs instalados en TU máquina
0.3  pregunta 1 (multi): ¿qué testing querés activo?
     interfaz/E2E · base de datos · calidad de código · seguridad · API/contratos · performance
0.4  pregunta 2 (multi): ¿qué skills/MCPs son proactivos de los devs?
0.5  calcula el plan de fan-out: cuántos subagentes y en qué orden
0.6  propone el roadmap por fases y ESPERA tu OK
1..N fases: dev → testers (por oleadas) → gate → cierre (docs + commit + push)
```

### El plan de fan-out (lo que evita que los testers se pisen)

| Regla | Consecuencia |
|---|---|
| **R1** · Un solo escritor a la vez | Los testers que **arreglan** van **en serie**; el dev congela el árbol antes |
| **R2** · Read-only en paralelo | Auditor de seguridad y tester de calidad, **a la vez** |
| **R3** · Recursos compartidos en serie | Navegador y base de datos: uno a la vez |
| **R4** · Superficie solapada | Si dos escriben en el mismo path, el 2º **re-corre las baterías** del 1º |
| **R5** · Orden por costo | Primero lo barato y rápido, después lo caro |
| **R6** · Sin interrupciones | Cada subagente es autónomo, con brief propio en disco |

El resultado va escrito en el roadmap, así podés corregirlo antes de arrancar:

```
Ola 0  dev (escritor)                      → entrega + árbol congelado
Ola 1  auditor de seguridad  ┐ en paralelo
       tester de calidad     ┘
Ola 2  tester de interfaz    ┐ en serie (el 2º re-corre las baterías del 1º)
       tester de base de datos┘
Ola 3  gate del orquestador + cierre
```

---

## Qué hay adentro

```
web-dev-loop/
├─ install.ps1 / install.sh      instaladores
├─ skills/web-dev-loop/
│  ├─ SKILL.md                   el procedimiento (bootstrap + loop + fan-out)
│  ├─ references/
│  │  ├─ capabilities.md         catálogo de dominios, inventario, formato de las preguntas
│  │  ├─ roles.md                anatomía de cada rol, cómo se briefea, cómo se leen los resultados
│  │  ├─ lessons.md              clases de fallo transversales (pre-vuelo de cualquier dev)
│  │  ├─ adapters/               una ficha por herramienta: cómo se usa y qué trampas tiene
│  │  └─ templates/              brief, roadmap, informe de dev, informe de tester
│  ├─ scripts/                   harness, runner de baterías y scaffolders
│  └─ assets/                    lo que recibe un proyecto nuevo
└─ agents/                       los cinco agentes nativos (con permisos)
```

### El stack de testeo, en tres capas

| Capa | Archivo | Qué resuelve |
|---|---|---|
| **Qué hay** | `testing/registry.json` | Proyecto, gates, testers y sus capacidades. El orquestador no adivina: lee. |
| **Cómo se usa cada herramienta** | `references/adapters/*.md` | Cómo se invoca, qué puede y qué no puede afirmar, y las trampas (incluidas las que ya nos costaron rondas). |
| **El idioma común** | `scripts/harness.mjs` | `check`/`equal`/`step`/`skip`/`cleanup`/`finish`, salida parseable `RESULT ok=N fail=M` y exit code. Un tester de base de datos y uno de UI producen salidas comparables. |

`scripts/run-batteries.mjs` corre varias baterías y **suma** los números de dominios
distintos:

```bash
node tools/run-batteries.mjs --glob "scripts/tester-*/0*.mjs"
```

### Empezar un proyecto nuevo

La skill trae los scaffolders:

```powershell
powershell -File scripts/new-project.ps1 -Name mi-app -Path C:\ruta -Port 3100
```

Crea la estructura, el `AGENTS.md` con las reglas del proyecto, el `opencode.jsonc`, el
registry, el harness y las carpetas de testers.

### Sumar un tester (interfaz, base, calidad, perf, API, seguridad)

```powershell
powershell -File scripts/new-tester.ps1 -Domain db -Name "Tester de base de datos" `
  -Capabilities invariantes,indices,concurrencia -Adapter sql
```

Crea el contrato del agente, sus baterías y **lo registra**. No hay que tocar nada más:
el orquestador lo ve en el registry y lo planifica en las oleadas.

---

## Los agentes

| Agente | Qué hace | Escribe | Commitea |
|---|---|---|---|
| `dev` | implementa una fase, se auto-ataca, corre sus gates | sí | **no** (por permiso) |
| `tester-ui` | usa la app en un navegador real, mide geometría y taps | sí | **no** |
| `tester-db` | invariantes, índices, concurrencia, reconciliación | sí | **no** |
| `tester-quality` | tipos, lint, complejidad, cobertura útil, deuda | no | **no** |
| `security-auditor` | hallazgos reproducibles por severidad | **no** | **no** |

Los permisos son del runtime, no de la confianza: `deny` explícito a `git commit` /
`git push` para todos menos el orquestador, y `deny` a `edit` para el auditor.

---

## Requisitos

- [OpenCode](https://opencode.ai) (V2) — es quien lee skills, agentes y permisos.
- Node 18+ para el harness y el runner de baterías (opcional: sólo si vas a escribir
  testers).
- Las herramientas que uses para testear (runner de UI, cliente SQL, linter…). Cada una
  tiene su ficha en `references/adapters/`.

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
