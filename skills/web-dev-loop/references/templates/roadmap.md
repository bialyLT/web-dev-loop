# Propuesta de trabajo — <PROYECTO>

**Fecha:** `<YYYY-MM-DD>` · **Meta:** `<qué tiene que ser verdad al final>` · **Rol:** propuesta

---

## 1. La meta, en una frase

`<el resultado observable que define el éxito>`

## 2. Qué testers quedan activos (elegidos por la persona)

| Dominio | Herramienta | Escribe código | Recurso | Superficie | Ola |
|---|---|---|---|---|---|
| `<dominio>` | `<herramienta>` | sí/no | `<recurso>` | `<paths>` | `<ola>` |

**Reglas aplicadas:** R1 un solo escritor · R2 read-only en paralelo · R3 recursos en serie ·
R4 solapamiento = serie + re-corrida · R5 orden por costo · R6 sin interrupciones.

**Cobertura por fase:** tabla de fases × dominios. Las celdas vacías son **huecos
declarados**: esa fase no tiene cobertura automática de ese dominio.

## 3. Qué usan los devs por su cuenta (proactivos)

`<skills/MCPs elegida por la persona>`

## 4. Roadmap por fases

### Fase 1 — `<nombre>`

- **Objetivo:** `<...>`
- **Criterios de aceptación (medibles):**
  1. `<criterio con número>` — cómo se mide
  2. `<...>`
- **Invariantes que no se rompen:** `<...>`
- **Gates:** `<typecheck / tests / smoke / build / flows>`
- **Testers:** `<dominio> (ola <n>)` · **Fuera de fase:** `<qué no se hace acá>`
- **Depende de:** `<fase previa o —>`

### Fase 2 — `<nombre>`

- ... (misma estructura)

## 5. Plan de ejecución de los testers

```
Ola 0  dev (escritor)                      -> entrega + árbol congelado
Ola 1  <read-only>            ┐  en paralelo
       <read-only>            ┘
Ola 2  <escritor>             ┐  en serie (el 2º re-corre las baterías del 1º)
       <escritor>             ┘
Ola 3  gate del orquestador + cierre
```

## 6. Riesgos yhuecos declarados

- `<...>`

## 7. Preguntas abiertas (si las hay)

- `<...>`

---

**Esperando OK explícito para arrancar la Fase 1.**
