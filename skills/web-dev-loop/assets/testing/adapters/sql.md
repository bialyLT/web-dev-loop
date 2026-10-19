# Adapter: SQL (sondas directas a la base)

## Qué es

Ejecución de consultas contra la base para verificar lo que la app **dice** contra lo que la
base **guardó**, y para atacar invariantes, índices y concurrencia.

## Cómo se invoca

- El `psql` portable del proyecto (Postgres 17 en `{{PG_DIR}}`, puerto `{{DB_PORT}}`).
- Las variables `DATABASE_URL` (dev) y `DATABASE_URL_TEST` (tests) del `.env`.
- **Nunca** contra producción sin confirmación explícita.

```powershell
psql "$env:DATABASE_URL_TEST" -c "select count(*) from movements where id like 'test-%';"
```

En Node: el cliente `pg` del proyecto (misma URL, pool propio y cerrado al terminar).

## Qué puede y qué no puede afirmar

| Puede | No puede |
|---|---|
| Verificar invariantes reales (CHECK, trigger, índice único) | Probar la UI |
| Medir performance con `EXPLAIN (ANALYZE, BUFFERS)` | Afirmar nada de la app sin probarla |
| Simular concurrencia con dos conexiones | Medir tiempos de red del navegador |
| Reconciliar totales al centavo | Sustituir los tests de integración |

## Trampas

| Síntoma | Causa | Qué hacer |
|---|---|---|
| La consulta devuelve 0 filas | Estás en la **base equivocada** (dev vs test) | Verificá la URL antes de cada sonda |
| "la app no guarda" pero la fila está | La app guarda en otra base / otra esquema | Mirá la `DATABASE_URL` del proceso que corre |
| La prueba "pasa" contra la base de dev | Apuntaste mal el DSN | Usá siempre `DATABASE_URL_TEST` para sondas |
| Deadlock en la prueba de concurrencia | Las dos transacciones tomó locks en orden distinto | Ordená los locks o usá `lock_timeout` |
| La carga de prueba dejó datos | No limpiaste por id | Contá y borrá por id al final |

## Reglas

1. **Sondas contra la base de tests.** La de dev es del usuario.
2. **Ids únicos por corrida** (prefijo tipo `t7r2-`) para poder limpiar sin ambigüedad.
3. **Limpieza por id**, siempre, y **verificá con un count** que quedó 0.
4. Para probar rollback: hacé la operación dentro de una transacción y confirmá que
   **no** quedó nada.
5. Para probar concurrencia: **dos conexiones reales** en paralelo (no dos queries en la
   misma conexión: eso se serializa solo y esconde el bug).
6. `EXPLAIN` sin `ANALYZE` para no ejecutar; `ANALYZE` sólo en queries de lectura.

## Limpieza

```sql
delete from movements where id like 't7r2-%';
```
Y después un `select count(*)` que dé **0**.
