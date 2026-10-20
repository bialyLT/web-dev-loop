# Capacidades: catálogo de testing, inventario y selección

## 1. Inventario (antes de preguntar)

Preguntar sin saber qué hay instalado hace trabajar al usuario de más. Inventariá **antes**
de armar las opciones.

```powershell
# skills instaladas (globales, de proyecto y compatibles)
Get-ChildItem "$HOME\.config\opencode\skills" -Directory -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Name
Get-ChildItem "$HOME\.claude\skills","$HOME\.agents\skills" -Directory -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Name

# MCPs configurados
$cfg = Get-Content "$HOME\.config\opencode\opencode.json" -Raw | ConvertFrom-Json
$cfg.mcp.servers.PSObject.Properties | ForEach-Object { $_.Name }
$cfg.mcp.PSObject.Properties | Where-Object { $_.Name -ne 'servers' } | ForEach-Object { $_.Name }
```

Para cada skill, leé el frontmatter de su `SKILL.md` (`name`, `description`): eso es lo que el
modelo ve cuando decide si la carga. Si un directorio de skills está **vacío**, no lo
ofrezcas: no va a poder cargarse.

**Además, el proyecto puede tener herramientas propias**: un runner de UI en `scripts/`, un
`flows/`, sondas SQL, un linter. Mirá `package.json` (scripts), `testing/registry.json` (si
existe) y la carpeta de herramientas antes de proponer.

## 2. Catálogo de dominios → herramientas

Este catálogo es el **menú base**. Se enriquece con lo que haya instalado.

| Dominio | Herramientas tipicas | Que compra | skill/MCP |
|---|---|---|---|
| **Interfaz / E2E** | Maestro CLI, sondas CDP | Camino feliz en navegador real, geometria, taps, accesibilidad, flows durables | runner de UI del proyecto |
| **Base de datos** | `psql` portable, cliente `pg` | Invariantes en la base, indices, triggers, concurrencia, reconciliacion al centavo | — |
| **Calidad de codigo** | `tsc`, ESLint, complejidad, cobertura, `knip`, `jscpd` | Salud estructural, deuda, codigo muerto, duplicacion | — |
| **Seguridad** | auditor read-only, `npm audit` | Hallazgos reproducibles por severidad | agente `security-auditor` |
| **API / contratos** | tests de integracion, OpenAPI | Cuerpos hostiles, limites, idempotencia, status codes | — |
| **Performance** | k6, scripts de timing, `EXPLAIN` | Presupuestos de latencia y de carga | — |
| **Responsive / mobile** | emulacion de device por CDP, auditoria barriendo un rango de anchos | Que nada se desborde en 320-1024 px y que los targets tocables lleguen a 44 px | — |
| **Documentacion** | context7 | Docs actuales de librerias (proactivo del dev) | MCP `context7` |
| **Memoria** | engram | Decisiones y cierres entre sesiones (proactivo del dev) | MCP `engram` |

## 3. Formato de las preguntas

**Una pregunta por vez, multi-selección, con el costo a la vista.** La herramienta
`question` con `multiple: true`.

### Pregunta 1 — qué testers se activan

```
header: "Testing"
question: "¿Que testing queres activo para este proyecto? (los que marques se planifican como subagentes; los demas se apagan)"
options:
  - "Interfaz / E2E — flows en navegador real + geometria de taps"
  - "Base de datos — invariantes, indices, concurrencia, conciliacion al centavo"
  - "Calidad de codigo — tipos, lint, complejidad, cobertura util, codigo muerto"
  - "Seguridad — auditor read-only: hallazgos reproducibles por severidad"
  - "API / contratos — cuerpos hostiles, limites, idempotencia"
  - "Performance — presupuestos de latencia y carga"
  - "Responsive / mobile — que nada se desborde en 360-430 px y los targets lleguen a 44 px"
```

Si el usuario no marca ninguno: se sigue, pero **decí** que la fase queda sin cobertura
automática y anotá la decisión.

### Pregunta 2 — qué es proactivo para los devs

```
header: "Proactivo dev"
question: "¿Que skills/MCPs usan los desarrolladores por su cuenta, sin que se lo pidan?"
options:
  - "Documentacion al dia (context7) — antes de usar una API que no conoces"
  - "Memoria persistente (engram) — decisiones y cierres entre sesiones"
  - "Exploracion del codigo — mapa de dependencias antes de tocar"
  - "Revision adversarial — riesgo, confiabilidad, legibilidad, resiliencia"
  - "Ninguno por ahora"
```

### Pregunta 3 — sólo si el proyecto ya tiene testers y hay que repartirlos

```
header: "Reparto"
question: "¿Como reparto los testers entre las fases?"
options:
  - "Por fase (recomendado) — cada fase activa solo los testers que le corresponden"
  - "Todos en cada fase — maximo de cobertura, mas tiempo de maquina"
```

## 4. De la selección al plan (tabla de oleadas)

Completá esta tabla antes de proponer el roadmap. Es lo que convierte "quiero estos testers"
en "estos subagentes, así y en este orden".

| Dominio | Herramienta | Escribe codigo? | Recursos | Superficies | Ola |
|---|---|---|---|---|---|
| Interfaz | Maestro + CDP | si (arregla) | navegador, server | `components/`, `app/` | 2 |
| Base de datos | SQL | si (arregla) | base de datos | `prisma/`, `lib/` | 2 |
| Calidad | tsc/eslint | no | repo (read) | — | 1 |
| Seguridad | auditor | no | repo (read) | — | 1 |

**Reglas para llenarla:**

- **R1 · Un solo escritor a la vez.** Los que escriben van **en serie** (ola 2+). El dev
  entrega y congela antes.
- **R2 · Read-only en paralelo.** Los que no escriben van **en paralelo** (ola 1).
- **R3 · Recursos compartidos en serie.** Navegador y base de datos: uno a la vez, salvo
  recursos separados (distinta base, distinto puerto).
- **R4 · Superficie solapada = serie + re-corrida.** Si dos escriben en el mismo path, el
  segundo **re-corre las baterías** del primero.
- **R5 · Orden por costo.** Primero lo barato y rápido, después lo caro (suite de UI,
  carga).
- **R6 · Sin interrupciones.** Cada subagente es autónomo, con su brief en disco; se lanzan
  en background y el orquestador **no** les pregunta estado.

**Olas resultantes (ejemplo):**

```
Ola 0  dev (escritor)                      -> entrega + arbol congelado
Ola 1  auditor de seguridad  ┐  en paralelo
       tester de calidad     ┘
Ola 2  tester de interfaz    ┐  en serie (arreglan; el 2º re-corre las baterías del 1º)
       tester de base de datos┘
Ola 3  gate del orquestador + cierre
```

Si sólo hay un tester, se puede correr **en paralelo con el dev** si es read-only; si
escribe, no (R1).

## 5. Cobertura por fase

Cada fase del roadmap declara qué testers corren y en qué ola. Si una fase no tiene tester
para su dominio, **decílo explícitamente en el roadmap** ("esta fase no tiene cobertura
automática de X"): es información que el usuario necesita, no un detalle.
