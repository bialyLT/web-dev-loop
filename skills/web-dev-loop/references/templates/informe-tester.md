# Informe tester — <FASE> <ronda> (<DOMINIO>)

**Rol:** tester adversarial independiente · **Fecha:** `<YYYY-MM-DD>` · **Repo:** `<ruta>`
**Método:** usar → encontrar → reproducir (falla primero) → arreglar → verificar.

---

## 1. Resultado en una línea

`<N checks ok · 0 fallas> · suite `<N/N>` · criterio `<medido>`

## 2. Baterías nuevas (`scripts/tester-<dominio>/`)

| Batería | Ataque | Qué verifica | Corrida final |
|---|---|---|---|
| `<file>` | `<...>` | `<...>` | `<N ok · 0>` |

## 3. Bugs encontrados y arreglados

### B1 · `<título>` — severidad `<alta/media/baja>`

- **Repro (falla primero):** `<batería + sección + log>` → `<N ok · M fallas>`
- **Causa:** `<archivo:línea>` — `<por qué>`
- **Arreglo:** `<qué se cambió>`
- **Verificado:** `<log>` → `<N ok · 0>`

## 4. Bugs que NO arreglé

- `<...>` — **por qué** `<...>`

## 5. Verificación de los claims del dev

| Claim | Verificación |
|---|---|
| `<claim>` | ✅ / ⚠️ `<cómo lo comprobé>` |

## 6. Números canónicos

| Bloque | Resultado | Evidencia |
|---|---|---|
| Regresión (ronda anterior) | `<...>` | `<log>` |
| Baterías nuevas | `<...>` | `<log>` |
| Suite completa | `<...>` | `<dir>` |
| Criterio medido | `<...>` | `<log>` |
| **Total** | `<...>` | |

## 7. Estado que dejo

- **Server:** `<PID/puerto>` · **Base:** `<residuos = 0>` · **Árbol:** sin commitear, con `<...>`
- **Residuos medidos:** `<...>`

## 8. VEREDICTO

**VEREDICTO: VERDE|ROJO** — `<razón en una frase con los números>`
