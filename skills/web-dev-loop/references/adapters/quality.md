# Adapter: calidad (tipos, lint, cobertura, complejidad, dependencias)

## Qué es

Conjunto de herramientas que miden la **salud estructural** del proyecto. El adapter define
cómo se corren **en modo lectura** y cómo se interpretan los resultados, para que el
tester de calidad reporte impacto y no ruido.

## Cómo se invoca (ejemplo: Node + TypeScript — adaptá al stack)

| Herramienta | Comando | Qué mide |
|---|---|---|
| Tipos | `npx tsc --noEmit` | Errores de tipos (modo estricto) |
| Lint | `npx eslint . --max-warnings 0` | Reglas de estilo y correctitud |
| Complejidad | `npx eslint . --rule '{"complexity":["warn",10]}'` | Funciones con demasiadas ramas |
| Código muerto | `npx knip` | Exports, imports y archivos sin uso |
| Duplicación | `npx jscpd . --min-lines 10` | Copias de lógica entre caminos |
| Cobertura | `npx vitest run --coverage` | Líneas covered vs totales |
| Dependencias | `npm audit --json` | CVEs con evidencia real |
| Higiene | `git ls-files` + grep | `.env` versionado, archivos gigantic, secretos |

## Reglas (importantes)

1. **Nunca con `--fix` ni `--write`**: el tester de calidad **reporta**, no reformatea.
   Un reformateo masivo esconde el hallazgo y ensucia el diff de la ronda.
2. **Un finding sin impacto es ruido.** El formatter se encarga del estilo; si la
   herramienta se queja de eso, no es un finding.
3. **Un finding sin ubicación exacta no es un finding**: `archivo:línea`.
4. **Contá por severidad.** "37 findings" no dice nada; "0 blockers, 3 warnings, 34
   suggestions" sí.
5. **La cobertura no es el objetivo.** Un 90% con la lógica crítica sin cubrir es peor
   que un 60% con los invariantes cubiertos. Leé **qué** está covered.
6. **`npm audit` con evidencia**: la severidad de la herramienta no es la severidad real.
   Un CVE en una dependencia que no se usa en runtime no es un riesgo alto. Decilo así.
7. **Compará contra la base**: un finding que ya estaba antes de la ronda no es de esta
   ronda (marcá `pre-existing`).

## Salida esperada

- Un archivo de resultados por herramienta en `reports/quality/` (JSON).
- Un informe con la tabla de findings (severidad, ubicación, impacto, evidencia) y el
  **número por severidad**.
- La lista de findings **no** arreglados, con el motivo.
