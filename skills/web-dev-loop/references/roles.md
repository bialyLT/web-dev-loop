# Roles: anatomía, brief y lectura de resultados

## 1. Los roles

| Rol | Escribe codigo | Commitea | Adiestra al adversario | Parallelo con otros |
|---|---|---|---|---|
| **Dev** | si | no | se auto-ataca antes de entregar | solo, es el escritor |
| **Tester <dominio>** | si (los que arreglan) | no | es su trabajo | serie con otros escritores; paralelo con los read-only |
| **Auditor** | no | no | no | paralelo con los read-only |
| **Orquestador** | si (el suyo) | **si, el unico** | no | — |

## 2. Reglas del contrato

1. **Un solo escritor a la vez.** Mientras alguien escribe, nadie mas escribe.
2. **El orquestador es el unico que commitea y pushea.** Los agentes dejan el arbol listo.
3. **El tester es independiente.** No cree al dev: reproduce sus claims.
4. **Todo bug con repro que falla primero.**
5. **Los testers no tocan schema ni migraciones**: reportan.
6. **Los agentes no se interrumpen**: corren autonomos, con brief en disco.

## 3. Anatomía de un brief (lo que necesita un subagente)

El subagente arranca con contexto fresco: el brief es su unica entrada.

```markdown
# Brief — <fase> <ronda> (<rol>)

**Repo:** <ruta>  **Punto de partida:** <commit>  **Árbol:** congelado / sos el unico escritor
**Rol:** <qué hacés>  **No** commiteás. No editás <docs del orquestador>.

## Objetivo
<qué tiene que quedar hecho, en una frase>

## Alcance
- Podés tocar: <paths exactos>
- No podés tocar: <paths>
- <migraciones: sí/no>

## Criterios de aceptación (medibles)
1. <criterio con número> — cómo se mide y quién lo mide

## Invariantes que no se rompen
- <regla del dominio>

## Contexto obligatorio
- <archivos a leer, con ruta>

## Reglas transversales
- <las del proyecto: fechas, valores exactos, errores, geometría, runners>

## Lo que vas a atacar (si sos tester)
- <enumerado: el tester verifica, no descubre>

## Gates
<comandos exactos y qué número se espera>

## Entregables
1. <código/tests>
2. Gates con números
3. Informe en <ruta>
4. Memoria
5. Mensaje final que empiece con <ENTREGADO:/VEREDICTO:>
```

**Reglas para escribir un brief:**

- **Criterios medibles, no intenciones.** "≤3 interacciones y ≤1 s, medido con taps reales"
  es un criterio; "que sea rápido" no lo es.
- **Enumerá lo que el tester va a atacar.** Si no lo enumerás, lo descubre y cuesta una ronda.
- **Fijá el entorno**: puerto, base, si el server está arriba, y la regla de pararlo antes de
  buildear.
- **Prohibí lo que no se toca**, con paths.
- **Pedí entregables exactos**: dónde va el informe, qué números, qué formato de mensaje.

## 4. Lectura de resultados

| Mensaje | Significado | Qué hace el orquestador |
|---|---|---|
| `ENTREGADO:` | El dev terminó con gates verdes | Congelar árbol, lanzar testers de la ola 1/2 |
| `BLOQUEADO:` | No puede seguir sin una decisión | Preguntar al usuario (una pregunta) |
| `VEREDICTO: VERDE` | Los testers no tienen hallazgos pendientes | Gate delta + cierre |
| `VEREDICTO: ROJO` | Hay hallazgos pendientes | Volver al tester que los encontró (no arreglar en el orquestador) |
| `HALLAZGOS:` / `HALLAZGOS: NINGUNO` | Auditor read-only | Sumarlo al criterio de salida de la fase |

Si un subagente **se cierra a mitad** (quedó esperando un comando en background): retomalo
con su id de sesión y dale el cierre explicito. No lo des por entregado.

## 5. Cierre de fase (checklist del orquestador)

- [ ] Gates post-fix en verde, con números **de esta corrida**.
- [ ] Árbol = el que midió el tester (mtimes del build vs. último cambio).
- [ ] Docs con el estado **real** verificado (no el planeado).
- [ ] Números canónicos en un solo lugar y iguales en todos lados.
- [ ] Un commit, mensaje convencional ASCII, sin atribución de IA.
- [ ] Push verificado (`HEAD` vs `ls-remote origin`).
- [ ] Memoria: decisiones, clases de fallo, números, próximo paso.
- [ ] `ROADMAP.md` y los informes fuera del repo (o en carpetas ignoradas).
