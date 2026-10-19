# Lecciones — clases de fallo transversales

> Este archivo es el **checklist de pre-vuelo** de cualquier dev o tester del kit.
> No para evitar la repetición exacta de un bug, sino para **reconocer el tipo** de problema.
>
> Regla de la casa: **un test que tapa una lección no la poda.** La lección es conocimiento
> transferible; el test es sólo el candado de la instancia.
>
> Origen: destilado de varias rondas reales de un proyecto de producción (un loop
> dev → tester → gate → cierre de ~10 fases, con auditoría de seguridad incluida).
> Cada clase es **agnóstica del dominio**: el ejemplo es ilustrativo, la regla es general.

---

## A. API y servidor

### A1 · El dedupe no serializa
**Síntoma:** dos peticiones concurrentes duplican filas.
**Causa:** el "comprobar si existe" y el "insertar" corren en transacciones separadas: los dos
leen "no existe".
**Arreglo:** dedupe + insert en la **misma transacción**, serializados con
`pg_advisory_xact_lock` o `SELECT … FOR UPDATE`.
**Generaliza:** toda operación que puede correr dos veces necesita idempotencia **real**; si
depende de un read previo, necesita un lock.

### A2 · Coerción laxa
**Síntoma:** `"1"`, `true` o `["2029-01-01"]` se aceptan como datos reales.
**Causa:** `Number(x)` / `String(x)` sobre input sin validar tipo.
**Arreglo:** `typeof` estricto (número entero o string con validador), nunca coerción suelta.

### A3 · Byte NUL
**Síntoma:** 500 en un id o en un texto con `\u0000`.
**Causa:** es una secuencia UTF-8 inválida para Postgres (22021) y muere **antes** de buscar.
**Arreglo:** id con NUL → 404 "no existe"; texto con NUL → 400, con regla genérica.

### A4 · El 500 que culpa a los datos
**Síntoma:** error 500 genérico cuando el problema es la infraestructura (pool agotado,
timeout).
**Arreglo:** traducir a 4xx/503 **accionable** ("reintentá en unos segundos"), en lecturas
también. Nunca un 500 que eche la culpa al usuario.

### A5 · Cuerpo JSON que no es un objeto
**Síntoma:** 500 al leer propiedades de `null`, string o array.
**Arreglo:** guard de objeto (`typeof body === 'object'`) antes de leer cualquier propiedad.

### A6 · Dos caminos que calculan o formatean el mismo número
**Síntoma:** la vista previa promete un valor y el alta guarda otro; o un monto que llega
precargado se muestra `4321.50` donde el campo es `4321,50`.
**Arreglo:** mismo normalizador en ambos caminos + **prueba de paridad con el string crudo**.

### A7 · Opciones cruzadas
**Síntoma:** el sistema ofrece una combinación imposible (por ejemplo: origen = destino en
un traslado entre cuentas).
**Arreglo:** al elegir uno, recalcular/excluir las opciones del otro. **Probá el par
prohibido**, no sólo los caminos felices.

### A8 · La invariante que vive sólo en la app
**Síntoma:** una regla del dominio que la base no conoce.
**Arreglo:** CHECK, índice único (parcial si hace falta) o trigger, en la **misma migración**
que introduce la feature.

### A9 · El error de estado "no existe" que no es idempotente
**Síntoma:** un POST duplicado devuelve 409 y el cliente no puede reintentar.
**Arreglo:** decidir explícitamente la semántica (idempotente o conflicto) y documentarla.

---

## B. Datos, valores y fechas

### B1 · Float
Si tu dominio maneja montos o decimales exactos: nunca `float`, nunca centavos en `Int`.
`Decimal` (o un equivalente de punto fijo) de punta a punta; los valores viajan como string y el
cliente calcula en enteros.

### B2 · Fecha de calendario vs instante
`@db.Date` + parseo local explícito; leer con `getUTCDate()`. Nunca `toISOString()` para una
fecha de negocio.

### B3 · "Hoy" literal
**Síntoma:** el test o el flow falla al día siguiente.
**Arreglo:** calcular la fecha; y **anotar el límite de calendario** de cada flow
("vale hasta el 10/11/2026").

### B4 · Truncar la lista y no el total
El tope de filas limita **lo que se muestra**, nunca **lo que se calcula**. Si el total
depende de filas que no volviste a traer, el número miente.

---

## C. UI

### C1 · Control tapado por una capa fija
**Síntoma:** el tap "completa" sin foco, sin error, y **el dato se pierde en silencio**.
**Causa:** pie sticky, toast u overlay por encima del control.
**Regla:** la geometría se juzga por el **punto de toque**, no por visibilidad. Medí la banda
de la capa con la ventana real y revisá **cada estado**, no sólo el reposo.

### C2 · Ayuda desplegable que empuja el layout
Al aceptar una sugerencia, **colapsala**: ya cumplió su función. Si queda abierta, empuja
campos vivos hacia la banda muerta.

### C3 · Overlay que se come los clicks
El toast/overlay va `pointer-events-none`, y el punto de toque del control de abajo tiene que
seguir llegando al control (verificá con `elementFromPoint`).

### C4 · Handlers de Escape anidados
El handler más específico hace `preventDefault()`; el global **tiene que respetar
`event.defaultPrevented`**. Si no, Escape cierra todo y descarta lo cargado.

### C5 · Diálogo nativo tumba al driver
`window.confirm` / `alert` / `prompt` **no** tienen nodo que contestar: el hilo de JS se
bloquea y muere el paso siguiente con un error que no lo menciona. Confirmá en línea, en la
propia fila.

### C6 · Atajo global
Guardas dobles: fuera de inputs/textarea/select/contentEditable **y** sin modal abierto; y
la minúscula sigue siendo **dato** dentro de un input (`t` en un campo de texto).

### C7 · Acción nueva que agrega altura
Un control nuevo en un modal con pie fijo empuja los de abajo. Medilo contra la banda en el
reposo de **cada estado** (distintos formularios o vistas miden distinto).

---

## D. Arnés y medición

### D1 · La ventana real no es la que suponés
La ventana del runner no es 1024×600. Medí el viewport real antes de discutir geometría.

### D2 · La "ventana sorda"
El primer clic puede llegar al DOM sin reacción de React. Es artefacto de medición:
esperá la hidratación y reintentá **contando el reintento como interacción**.

### D3 · Los efectos colaterales de la carga
Algunas pantallas, al cargar, **materializan** trabajo pendiente (jobs, vencimientos,
generación de documentos): es comportamiento del producto, no contaminación del test.
**No asertes igualdad de un agregado entre recargas**; usá diff por id.

### D4 · La posición de un flow es parte de su contrato
Un flow que corre último hereda el estado de todos los anteriores: el "seed" caduca y los
desempates cambian. Validá la posición en la **suite completa**, no sólo aislado.

### D5 · Las precondiciones sobre "hoy" caducan después de la suite
Los flows cargan fixtures de hoy por diseño. Medí contra una **línea base** capturada, no
contra el vacío.

### D6 · Un runner a la vez
Dos runners (o un runner y su MCP) se pelean por la sesión y la memoria: el síntoma es un
flow que tarda el doble o muere en el primer `openLink` con un error que culpa a Chrome.

### D7 · Asertar por texto en una base sembrada
El seed repite descripciones genéricas. Filtrá por **cuenta o id**, nunca por descripción.

---

## E. Loop y cierre

### E1 · Un solo escritor a la vez
El dev escribe; cuando entrega, el árbol queda congelado y el tester pasa a ser el único
que escribe. Dos escritores = dos fuentes de verdad.

### E2 · El tester no cree al dev
Reproducí los claims del informe con tus propios ojos. Sin reproducción, es una opinión.

### E3 · Todo bug con repro que falla primero
Si no hay forma de ver la falla antes del arreglo, no hay bug reportado.

### E4 · Los números se miden, no se estiman
Un gate sin número no es un gate. Y si dos fuentes no coinciden, gana la que ejecutó el
comando.

### E5 · La regresión se corre **entera**
Las baterías de la ronda anterior se re-corren sin editarlas. Editar una batería para que
pase es borrar el candado.

### E6 · Cierre con evidencia
Números por gate + informe escrito + memoria + commit + push **verificado** (comparando
`HEAD` con `ls-remote`).

### E7 · Las lecciones no se podan
Un test que tapa una lección no la poda: la lección es conocimiento transferible.
