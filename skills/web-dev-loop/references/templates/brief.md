# Brief — <FASE> <ronda> (<ROL>)

**Repo:** `<ruta>` · **Punto de partida:** `<commit>` · **Árbol:** congelado / sos el único escritor
**Rol:** `<qué hacés>` · **No** commiteás · **No** editás `<docs del orquestador>`

## Objetivo

`<qué tiene que quedar hecho, en una frase>`

## Alcance

- **Podés tocar:** `<paths exactos>`
- **No podés tocar:** `<paths>` (docs del orquestador, migraciones ajenas, carpetas del harness)
- **Migraciones:** `<sí / no>`

## Criterios de aceptación (medibles)

1. `<criterio con número>` — **cómo se mide** y **quién lo mide**
2. `<...>`

## Invariantes que no se rompen

- `<regla del dominio>`

## Contexto obligatorio (leelo antes de tocar nada)

- `<ruta>` — `<qué hay que entender>`
- `<ruta>` — `<...>`

## Reglas transversales

- Fechas de calendario, nunca `toISOString()`; "hoy" se calcula, nunca literal.
- Si el dominio maneja montos o decimales exactos: `Decimal` de punta a punta; los valores viajan como string.
- Dedupe dentro de la misma transacción y con lock (consultar antes no serializa).
- Errores de infraestructura → 4xx/503 accionable, **nunca** 500 que culpa a los datos.
- UI: sin diálogos nativos; confirmaciones inline; toda UI nueva medida contra las capas
  fijas por **punto de toque** (banda del pie, toasts) en cada estado.
- `127.0.0.1`, nunca `localhost`. Un runner de UI a la vez.
- Build: **pará el server antes** de buildear (EPERM sobre binarios nativos) y relanzá
  detached.

## Lo que vas a atacar (si sos tester)

> Enumeralo vos: el tester **verifica**, no descubre.

- `<ataque 1>`
- `<ataque 2>`

## Gates

| Gate | Comando | Objetivo |
|---|---|---|
| Tipos | `<cmd>` | 0 errores |
| Tests | `<cmd>` | todos verdes, con número |
| Smoke / E2E | `<cmd>` | contra la app real |
| Build | `<cmd>` | EXIT=0 |

## Entregables

1. Código + migraciones + tests (o baterías, si sos tester).
2. Gates verdes **con números**.
3. Informe en `%TEMP%/<kit>/informe-<rol>-<fase>-<ronda>.md` — sin placeholders.
4. Memoria (Engram): decisiones, clases nuevas, números.
5. Mensaje final que empiece con `<ENTREGADO: | BLOQUEADO: | VEREDICTO:>` seguido de la
   evidencia.
