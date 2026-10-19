# Contrato de agentes — cómo se organiza y cómo se extiende

Este directorio es **modular por diseño**: los agentes no se conocen entre sí, se
**registran**. El orquestador lee el registro (`testing/registry.json`) y decide a quién
lanzar. Agregar un tester nuevo no obliga a tocar ningún agente existente.

---

## 1. Los roles (y por qué son distintos)

| Rol | Quién | Escribe código | Commitea | Adiestra al adversario |
|---|---|---|---|---|
| **Orquestador** | la persona + el agente principal | sí (el suyo) | **sí, el único** | no |
| **Dev** | subagente de ronda | sí | no | se auto-ataca antes de entregar |
| **Tester <dominio>** | subagente adversarial | **sí, pero de a uno** | no | es su trabajo |
| **Auditor** | subagente read-only | no | no | no |

Reglas que no se negocian:

1. **Un solo escritor a la vez.** Mientras el dev escribe, el tester no arranca. Cuando el
   dev entrega, el árbol queda **congelado** y el tester pasa a ser el único que escribe.
2. **El orquestador es el único que commitea y pushea.** Los agentes dejan el árbol listo
   y reportan; el commit lo hace el orquestador con los números verificados.
3. **El tester es independiente.** No lee el informe del dev como verdad: lo **reproduce**.
   Si el dev dice "arreglado", el tester lo comprueba con sus propios ojos.
4. **Todo bug lleva repro que falla primero.** Si no hay forma de ver la falla antes del
   arreglo, no hay bug reportado: hay una opinión.
5. **El tester puede arreglar** (es dev de la app), pero **no** puede tocar migraciones,
   schemas ni el modelo de dominio: ahí reporta y decide el orquestador.

## 2. Anatomía de un agente

Todo agente es **un archivo markdown con frontmatter** (V2 de OpenCode):

```markdown
---
description: Qué hace y cuándo hay que elegirlo   # se muestra al orquestador: es el selector
mode: subagent                                     # primary | subagent | all
model: provider/model#variant                      # opcional: si falta, hereda la del padre
permissions:                                       # opcional: límites duros
  - action: edit
    resource: "*"
    effect: deny
---

# Rol
Qué es y qué NO es. En una frase.

# Lectura obligatoria
Qué tiene que leer antes de tocar nada (con rutas exactas).

# Alcance
Qué puede y qué no puede tocar. Los paths exactos. Lo que no existe todavía.

# Método
El ciclo: usar -> encontrar -> reproducir -> arreglar -> verificar.

# Entregables
Qué devuelve y en qué formato. Sin placeholders.

# Cierre
Memoria + mensaje final.
```

Secciones obligatorias en todo agente: **Rol · Lectura obligatoria · Alcance · Método ·
Entregables · Cierre**. Si falta una, el agente improvisa y rompe el loop.

## 3. El registro: la fuente de verdad

`testing/registry.json` declara el proyecto y qué testers existen:

```jsonc
{
  "project": { "name": "mi-app", "appUrl": "http://127.0.0.1:3100" },
  "gates": { "typecheck": "...", "unit": "...", "build": "...", "flows": "..." },
  "testers": [
    { "id": "ui", "domain": "ui", "agent": "agents/tester-ui.md",
      "capabilities": ["interaccion", "geometria", "accesibilidad"],
      "adapters": ["maestro", "cdp"], "batteries": "scripts/tester-ui/" }
  ]
}
```

El orquestador **no adivina**: mira el registro, ve qué testers hay, y lanza al que cubra
el dominio del cambio. Si un dominio no tiene tester, el orquestador lo dice explícitamente
("este cambio no está cubierto por ningún tester del registro") en vez de fingir que sí.

## 4. Agregar un tester nuevo (5 minutos)

```powershell
powershell -File scripts/new-tester.ps1 -Domain db -Name "Tester de base de datos" `
  -Capabilities invariantes,indices,concurrencia -Adapter sql
```

Eso:

1. crea `agents/tester-db.md` desde la plantilla, con las secciones obligatorias ya armadas;
2. crea `scripts/tester-db/` con `lib.mjs` (wrapper del harness) y una batería de ejemplo;
3. **registra** el tester en `testing/registry.json`;
4. deja el tester listo para lanzar, sin tocar ningún otro archivo.

Si preferís hacerlo a mano, el mínimo es: un markdown en `agents/`, un folder de baterías y
**una entrada en el registry**. Nada más.

### 5. Agregar una herramienta nueva (adapter)

Una herramienta (Playwright, k6, SQLAlchemy, un linter, un fuzzer) se documenta como
**adapter** en `testing/adapters/<nombre>.md` con este contrato:

- **Cómo se invoca** (comando exacto, variables de entorno, precondiciones).
- **Qué puede y qué no puede afirmar** (ej: Maestro web no emite combinaciones de teclas).
- **Las trampas** (las que ya te están costando; ver `docs/lessons.md`).
- **Cómo se integra** (qué helper del harness usa, cómo se limpia lo que crea).

Después se agrega al `adapters` del tester correspondiente en el registry. El harness es lo
que **uniformiza**: cualquier batería, sea de UI, de base o de lint, habla el mismo idioma
(`check`, `cleanup`, resumen `ok=N fail=M`, exit code) y el agregador suma los números
igual. Por eso el stack escala sin rehacerse.

## 5. El loop, paso a paso

1. **Brief.** El orquestador escribe el brief de la ronda: alcance, criterios medibles,
   invariantes, lo que el tester va a atacar, entregables esperados. Va a un archivo
   (`%TEMP%/<kit>/brief-<ronda>.md`), no a la memoria del subagente.
2. **Dev.** Implementa, auto-ataca, corre sus gates, entrega con `ENTREGADO:` o `BLOQUEADO:`
   y deja el árbol **sin commitear**.
3. **Tester.** Corre sobre el árbol congelado: primero la regresión de lo que ya existía,
   después lo nuevo. Arregla lo que encuentra (de a uno) y deja repro que falla primero.
   Cierra con `VEREDICTO: VERDE|ROJO` y números.
4. **Gate.** El orquestador corre **delta** sobre el árbol congelado (lo que el tester no
   cubrió post-fix) y verifica que el árbol esté como el tester lo dejó.
5. **Cierre.** Docs (números reales, sin placeholders) → commit único → push verificado →
   memoria actualizada.
6. **Pausa o sigue.** Si la persona pidió pausa, ahí termina. Si no, se abre la ronda
   siguiente con el mismo loop.

## 6. Qué devuelve cada agente (contrato de entrega)

Todos los agentes devuelven **lo mismo en forma**:

- Un **mensaje final** que empieza con una palabra clave: `ENTREGADO:`, `VEREDICTO:`,
  `HALLAZGOS:`, `BLOQUEADO:`. El orquestador parsea esa primera palabra.
- Un **informe escrito** en disco (`%TEMP%/<kit>/informe-<rol>-<ronda>.md`), sin
  placeholders: lo que no se pudo verificar se dice explícitamente.
- **Números exactos** por gate: tests, checks, flujos, tiempos. Sin "aproximadamente".
- **Cierre en memoria** (Engram): decisiones, clases de fallo, estado del pipeline.

## 7. Nombres y paths

- Ids de agente: `dev`, `tester-<dominio>`, `<rol>-auditor`. El id es lo que se pasa al
  orquestador para lanzarlo.
- Dominios de tester previstos: `ui`, `db`, `quality`, `api`, `perf`, `security`.
  Se pueden agregar; no hacen falta todos para empezar.
- Carpetas de baterías: `scripts/tester-<dominio>/` con el prefijo numérico para ordenar.
- Informes y logs: **fuera del repo** (`%TEMP%`) o en carpetas gitignoradas.
