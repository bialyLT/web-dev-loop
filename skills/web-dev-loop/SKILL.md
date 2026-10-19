---
name: Web Dev Loop
description: Bootstrap y loop de desarrollo por fases para proyectos web con agentes (dev + testers adversariales). Usar cuando el usuario pide un roadmap con una meta, una propuesta de trabajo para una tarea, o avanzar/planificar una fase; y cuando hay que elegir que skills o MCPs de testing se activan, que skills o MCPs usan los devs, cuantos subagentes de testing van en paralelo o en serie, o correr el ciclo dev -> tester -> gate -> cierre.
metadata:
  opencode/autoinvoke: true
---

# Web Dev Loop

Procedimiento para proyectos web con agentes. Dos mitades: **(0) bootstrap** — del pedido a un
roadmap aprobado con testers decideos — y **(1) loop por fases** — de la fase al commit.

Idiomatico: español rioplatense con el usuario, inglés en el código.

---

## 0. Bootstrap: del pedido al roadmap aprobado

### 0.1 Clasificá el pedido

| El usuario pide | Qué hacés |
|---|---|
| **Un roadmap con una meta** (" quiero una app de X que llegue a Y ") | Fase 0 completa: inventario -> preguntas -> plan de testing -> roadmap por fases |
| **Una propuesta para una tarea** (" quiero que hagas Z ") | Fase 0lite: inventario -> **una** pregunta (qué testers) -> propuesta con criterios medibles -> OK -> fases |

En ambos casos **no arrancás a codear** hasta el OK explícito.

### 0.2 Inventariá las capacidades disponibles (antes de preguntar)

Preguntar sin saber qué hay instalado es hacer trabajar al usuario de más. Inventariá:

```powershell
Get-ChildItem "$HOME\.config\opencode\skills" -Directory | Select-Object -ExpandProperty Name
Get-Content "$HOME\.config\opencode\opencode.json" -Raw | ConvertFrom-Json | Select-Object -ExpandProperty mcp
```

Mapeá lo encontrado a **dominios de testing** (catálogo en `references/capabilities.md`):

| Dominio | Herramienta típica | Responde |
|---|---|---|
| Interfaz / E2E | Maestro CLI, sondas CDP | ¿la UI hace lo que dice, y la geometría no te mata datos? |
| Base de datos | `psql`, sondas SQL | ¿la base hace cumplir las invariantes y aguanta la concurrencia? |
| Calidad de código | `tsc`, ESLint, complejidad, cobertura | ¿la salud estructural aguanta? |
| Seguridad | auditor read-only, `npm audit` | ¿hay hallazgos altos o críticos reproducibles? |
| API / contratos | tests de integración, schemata | ¿los bordes y los cuerpos hostiles responden lo que deben? |
| Performance / carga | k6, scripts de timing | ¿el presupuesto de latencia se sostiene? |

### 0.3 Pregunta 1 — qué testers se activan

**Una sola pregunta, multi-selección.** Usá la herramienta `question` con `multiple: true` y
opciones concretas (dominio + herramienta + qué gana), no categorías vagas.

```
Interfaz / E2E        -> Maestro + sondas CDP: flows en navegador real, geometria y taps
Base de datos         -> SQL directo: invariantes, indices, concurrencia, reconciliacion
Calidad de codigo     -> tsc/eslint/complejidad/cobertura: deuda y salud estructural
Seguridad             -> auditor read-only: hallazgos reproducibles, sin arreglar
API / contratos       -> integracion: cuerpos hostiles, limites, idempotencia
Performance           -> carga y latencia: presupuestos de tiempo
```

Si el usuario no elige ninguno, se sigue igual (testing manual), pero **decí** que la fase
queda sin cobertura automática.

### 0.4 Pregunta 2 — qué skills/MCPs son proactivos para los devs

Segunda pregunta, también multi-selección. Son las herramientas que los **desarrolladores**
usan solas, sin que nadie se lo pida:

- **Documentación al día** (context7): antes de usar una API que no conocés.
- **Memoria persistente** (engram): decisiones y cierres entre sesiones.
- **Exploración del código** (codegraph / explore): mapa de dependencias antes de tocar.
- **Revisión adversarial** (review-*: riesgo, confiabilidad, legibilidad, resiliencia).
- **Otros** (los que tenga el sistema y el usuario nombre).

### 0.5 Calculá el plan de fan-out (cómo se lanzan los testers)

Cada dominio elegido se clasifica con tres preguntas, y de ahí sale **paralelo o serie**:

| Pregunta | Significado |
|---|---|
| ¿Escribe código? | Un dev o un tester que **arregla** necesita el árbol para él |
| ¿Qué recurso comparte? | Navegador (Maestro), base de datos, build, puerto |
| ¿Qué superficie toca? | Paths donde puede escribir (para detectar solapamiento) |

**Reglas (no negociables):**

- **R1 · Un solo escritor a la vez.** Mientras alguien escribe, nadie más escribe. Los
  testers que **arreglan** van **en serie**; el dev entrega y **congela el árbol** antes.
- **R2 · Los read-only van en paralelo.** Auditor de seguridad y tester de calidad se
  lanzan **a la vez** sobre el árbol congelado.
- **R3 · Los recursos compartidos se serializan.** Navegador y base de datos: uno a la vez
  (o bases separadas). Dos Maestro a la vez pelean el lock de sesión y la RAM.
- **R4 · Superficie solapada = serie + re-corrida.** Si dos testers escriben en el mismo
  path, el que va segundo **re-corre las baterías** del primero.
- **R5 · Orden por costo.** Primero lo barato y rápido (calidad, contratos), después lo caro
  (suite de UI completa, carga).
- **R6 · No se interrumpen.** Los subagentes corren **autónomos** (background), cada uno con
  un brief propio en disco; el orquestador no los interrumpe ni les pregunta estado.

Salida: una tabla de **oleadas** que va al roadmap.

```
Ola 0  dev (escritor)                  -> entrega + árbol congelado
Ola 1  auditor de seguridad  ┐  en      -> read-only, paralelos entre sí
       tester de calidad     ┘  paralelo
Ola 2  tester de interfaz    ┐  en      -> arreglan: en serie, ordenados por solapamiento
       tester de base de datos ┘  serie  (el 2º re-corre las baterías del 1º)
Ola 3  gate del orquestador + cierre    -> números, docs, commit, push
```

### 0.6 Proponé el roadmap y esperá el OK

Cada fase lleva: **objetivo**, **criterios de aceptación medibles** ("≤3 interacciones y
≤1 s, medido con taps reales"), **invariantes que no se rompen**, **gates**, **qué testers
corren y en qué oleada**, **qué queda fuera de fase**. El roadmap completo, en una tabla.

**Esperá el OK explícito antes de escribir código.** Un OK parcial ("sí, pero la fase 2
espera") es un OK parcial: seguí sólo con lo aprobado.

---

## 1. Loop por fase

### 1.1 Brief (un archivo, en disco)

Cada agente arranca con contexto fresco: el brief es su única entrada. Lleva alcance,
criterios medibles, invariantes, qué va a atacar el tester, entregables y **qué NO puede
tocarse** (docs del orquestador, migraciones ajenas, carpetas del harness).

### 1.2 Dev

Implementa, se auto-ataca, corre sus gates, entrega con `ENTREGADO:` o `BLOQUEADO:` y deja
el árbol **sin commitear**. Nunca commitea.

### 1.3 Testers (por oleadas, según 0.5)

- Primero la **regresión** de lo que ya existía (baterías enteras, sin editarlas).
- Después lo nuevo. Cada bug con **repro que falla primero**.
- Arreglan lo que corresponde (menos schema y migraciones: eso se reporta).
- Cierran con `VEREDICTO: VERDE|ROJO` y **números**.

### 1.4 Gate (orquestador, sobre el árbol congelado)

Corre **delta**: lo que el fix final dejó sin cubrir. Si el tester ya corrió build, suite y
tests sobre el árbol final, el gate es `typecheck` + `tests`. No repitas lo ya cubierto.

### 1.5 Cierre

Docs con números reales (no planeados) → **un commit** → push **verificado** (`HEAD` vs
`ls-remote`) → memoria (decisiones, clases de fallo, números, próximo paso).

### 1.6 ¿Siguiente fase o pausa?

Si el usuario pidió **pausa**, se frena todo y se deja el estado anotado. Si no, se abre la
fase siguiente con el mismo loop.

---

## 2. Reglas de la casa

1. **Un solo escritor a la vez**; el orquestador es el único que commitea y pushea.
2. **Los testers no creen al dev**: reproducen los claims con sus propios ojos.
3. **Todo bug con repro que falla primero**. Si no hay forma de ver la falla antes del
   arreglo, es una opinión.
4. **Los números se miden**: un gate sin número no es un gate. Si dos fuentes no coinciden,
   gana la que ejecutó el comando.
5. **La regresión se corre entera**; editar una batería para que pase es borrar el candado.
6. **Una acción nueva en la UI se mide contra las capas fijas** (banda del pie, toasts) por
   **punto de toque**, no por visibilidad: un tap muerto no da error, se pierde el dato.
7. **Sin diálogos nativos** (`window.confirm`/`alert`): tumban al driver web.
8. **Fechas dinámicas**: "hoy" se calcula, nunca literal. **127.0.0.1**, nunca `localhost`.
9. **Un runner de UI a la vez**; un MCP de Maestro y el CLI de Maestro no conviven.
10. **Commits**: convencionales, ASCII, sin atribución de IA. `ROADMAP.md` local-only.

Las clases de fallo completas están en `references/lessons.md`: son para **reconocer el
tipo** de problema, no para evitar la repetición exacta de un bug. Un test que tapa una
lección no la poda.

---

## 3. Referencias

| Archivo | Para qué |
|---|---|
| `references/capabilities.md` | Catálogo de dominios de testing, inventario de skills/MCPs, formato de las preguntas |
| `references/roles.md` | Anatomía de cada rol (dev, testers, auditor) y cómo se los briefea |
| `references/lessons.md` | Clases de fallo transversales (pre-vuelo de cualquier dev) |
| `references/adapters/*.md` | Cómo se usa cada herramienta y qué trampas tiene |
| `references/templates/*.md` | Brief, roadmap, informe de dev, informe de tester |
| `scripts/harness.mjs` | Harness común de baterías (`check`/`cleanup`/`finish`, salida `RESULT ok=N fail=M`) |
| `scripts/run-batteries.mjs` | Corre varias baterías y **suma** los números de dominios distintos |
| `scripts/new-project.ps1` | Scaffoldea un proyecto nuevo con esta skill instalada |
| `scripts/new-tester.ps1` | Registra un tester nuevo (contrato + baterías + registry) |
