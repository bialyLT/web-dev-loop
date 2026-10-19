# Protocolo de memoria persistente (Engram)

La memoria es lo que hace que un proyecto sobreviva a una sesión (o a una semana). Sin ella,
cada agente arranca de cero y vuelve a descubrir lo mismo.

## Reglas

1. **Guardá al cerrar cada frontera limpia**: decisión, bug, descubrimiento, patrón,
   configuración. No al final de todo: al final de cada cosa.
2. **No guardes lo que el repo ya dice.** El código, los tests y la documentación están en
   el repo; la memoria guarda el **porqué**, los números canónicos y el estado del pipeline.
3. **Números exactos**, nunca "más o menos". La memoria es la fuente de los números.
4. **Un tema estable por topic_key** (`fase7/ronda2-pipeline`, `testing/patron-baterias`):
   si el tema evoluciona, actualizá la misma observación en vez de crear una nueva.
5. **Si hay conflicto**, no lo resuelvas solo: registrá el veredicto con la evidencia.
6. **Session summary al terminar** una sesión: es lo que lee el próximo agente.

## Formato de una observación

```
**What**: una frase — qué se hizo.
**Why**: por qué (pedido del usuario, bug, performance, etc.).
**Where**: archivos o rutas afectadas.
**Learned**: lo que costó, los bordes, lo que sorprendió (omitir si no hay).
```

Tipos: `bugfix` · `decision` · `architecture` · `discovery` · `pattern` · `config` ·
`preference`.

## Qué guardar (y qué no)

| Guardar | No guardar |
|---|---|
| Decisiones de diseño con su trade-off | El contenido de un archivo del repo |
| Bugs con causa raíz | El código del fix |
| Números canónicos de una ronda | Salidas de comando largas |
| Patrones que se van a repetir | Frases de efecto |
| Preferencias del usuario | Conversación |
| Bloqueos que necesitan a una persona | Planes sin ejecutar |

## Conflicts

Cuando la memoria devuelve candidatos en conflicto:

1. Leelos y decidí con **evidencia**, no por memoria del título.
2. `related` si son etapas del mismo carril · `compatible` si conviven · `scoped` si uno
   aplica a un contexto más chico · `not_conflict` si no se tocan.
3. `supersedes` sólo con la evidencia de que el nuevo hecho **reemplaza** al viejo.
4. Si la confianza es baja (< 0.7), preguntale a la persona.

## Session summary (obligatorio antes de terminar)

```markdown
## Goal
[qué se hizo en la sesión]

## Instructions
[preferencias y restricciones descubiertas]

## Discoveries
- [hallazgo técnico, gotcha, comportamiento no obvio]

## Accomplished
- ✅ [tarea con detalle]
- 🔲 [identificado pero pendiente]

## Next Steps
- [qué queda para la próxima sesión]

## Relevant Files
- ruta — [qué hace o qué cambió]
```

## En un proyecto nuevo

1. Detectá el proyecto (`mem_current_project`) y usá ese nombre en todas las lecturas.
2. Leé `mem_context` al empezar (qué se hizo la última vez) y `mem_search` cuando el tema
   te sea desconocido.
3. Escribí el nombre del proyecto en `CONTEXTO.md` para que el próximo agente sepa dónde
   mirar.
