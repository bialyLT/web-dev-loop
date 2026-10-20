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

### C8 · El contenido que no puede achicarse rompe TODAS las vistas
**Síntoma:** en un teléfono, la página se ve chueca (texto microscópico) o hay scroll
horizontal en todas las pantallas.
**Causa:** un elemento con ancho mínimo fijo o no achicable — una fila de `flex` que no
envuelve, un `grid-cols-4` sin `sm:`, un `whitespace-nowrap`, una tabla, un `w-[Npx]`, un
nav con 5 links — **empuja el documento entero** a su ancho mínimo.
**Medida:** el **ancho del contenido** (`documentElement.scrollWidth`) contra el **ancho del
device**, no contra `innerWidth` (ver C9). Un solo nav sin wrap bastó para romper seis vistas
(375 → 664 px).
**Arreglo — y acá está lo importante:** que el layout se **adapte al espacio disponible**, no
que entre en una lista de teléfonos. En este orden: que el contenedor **envuelva**
(`flex-wrap`) · `min-w-0` en los hijos de flex para que puedan encogerse · **scroll propio**
cuando sea una tabla o una lista larga · **container queries** o `sm:`/`md:` sólo cuando de
verdad haga falta un cambio de disposición. Un `md:hidden md:block` por teléfono NO es
responsive: es responsive de juguete (entra en 375 y se rompe en 414).
**El criterio es un invariante sobre un RANGO**, no una lista de devices: "sin scroll
horizontal en **todo** ancho entre 320 y 1024". Si el layout depende de un breakpoint, se
rompe en el ancho que nadie probó.

### C9 · `innerWidth` miente cuando el contenido no puede achicarse
**Síntoma:** medís 664 px en un device de 375 y te parece que la emulación falló... o al revés:
medís "todo bien" en 664 y creés que estás en 375.
**Causa:** cuando el contenido no puede encogerse, Chrome **expande el viewport de layout**:
`innerWidth` crece al ancho del contenido (375 → 664) y deja de reflejar el device.
**Arreglo:** medí siempre contra el **ancho del device** (el que vos fijaste en la emulación) y
`documentElement.scrollWidth`. Si tu auditoría usa `innerWidth` como verdad, miente en dos
direcciones.

### C10 · Target táctil chico
**Síntoma:** en el teléfono se erran los botones; el usuario "no le da al botón".
**Regla:** todo control interactivo **≥ 44×44 px** de alto (el mínimo de ergonomía del dedo:
44 px CSS ≈ 11,6 mm; es un mínimo **humano**, no un breakpoint de diseño). La nav, los botones
de filtro, las flechas de mes y los chips de acción son los que más se olvidan. Los links
dentro de un párrafo son la excepción habitual.
**Y decidí por MODELEDAD, no por ancho:** `@media (pointer: coarse)` = "el usuario tiene el
dedo" → 44 px; un mouse no los necesita. Con un corte por ancho, un teléfono en landscape
(1024px) queda con targets chicos y una ventana angosta de escritorio los infla sin razón.

### C11 · En Tailwind (y en todo mobile-first) el teléfono es la BASE, no un breakpoint
**Síntoma:** el proyecto "usa responsive" y en el teléfono todo se rompe igual.
**Causa:** Tailwind v4 arranca en `sm: 40rem` (640px): **debajo de 640px no hay prefijo que
te salve**, y el layout base es el que se ve en el teléfono. Si el base se escribió pensando
en escritorio (una fila de `flex` que no envuelve, un `grid-cols-4`), en el teléfono no hay
"layout móvil": hay un layout de escritorio que se desborda.
**Regla:** el arrangement del teléfono va en las clases **sin prefijo** (fluidas: wrap,
`min-w-0`, `overflow-x-auto` donde corresponda) y los prefijos **agregan** disposición en
pantallas grandes. Un `sm:hidden sm:block` por teléfono no arregla nada: esconde el síntoma.
**Diagnóstico rápido:** contá los prefijos que el proyecto usa (`grep -o '\b\(sm\|md\|lg\|xl\):'`
). Si sólo usa `sm:` (o nada), el layout base es el de escritorio: el trabajo real es ahí.
**Con Tailwind v4 (CSS-first, sin `tailwind.config.js`):** el theme vive en el CSS global con
`@theme inline`, y las variantes propias se declaran con `@custom-variant` (ej.
`@custom-variant touch { @media (pointer: coarse) { @slot; } }` → `touch:min-h-11`).

### C12 · La zona muerta del pie pegajoso: el scroller tiene que TERMINAR donde empieza el pie
**Síntoma:** en un modal con pie fijo, un campo queda **debajo** de la banda; el dedo lo
toca y **despacha otro control** (un «Cancelar» que cierra y **descarta lo cargado**), o el
tap se pierde en silencio.
**Causa:** el pie es `sticky` **dentro** del área scrolleable: el contenido scrollea por
debajo de él.
**Arreglo:** el panel como **columna flex** — `flex-none` en el encabezado y el pie,
`flex-1 min-h-0 overflow-y-auto` en el área del formulario — así el área scrolleable
**termina** donde empieza el pie. Con el pie **fuera** del `<form>`, el botón de guardar se
referencia con `form="…"` (si no, Enter en un campo dispara el submit antes de tiempo).
**Medición:** malla de puntos sobre el rect **visible** de cada control + `elementFromPoint`:
tiene que dar **0 superficies partidas** (la persona ve un control y el tap despacha otro).
"Un aviso" (control bajo la banda pero alcanzable scrolleando) **no es** lo mismo que un
tap muerto: pero si **debajo** hay un botón disparativo, es un bug igual de grave.

### C13 · El contenido tiene que entrar en su caja
**Síntoma:** el documento no se desborda (el device está bien) pero **el número queda
cortado dentro de su tarjeta**.
**Por qué importa:** es una mentira igual de grave que el desborde: el panel muestra
`$ 800.000,0…`. Un gate que mide sólo el ancho del documento **no lo ve**.
**Arreglo:** que el texto **se ajuste al ancho de su caja** (container query con la unidad
`cqw`, o un cuerpo de letra proporcional) — no que se corte. Y **el gate tiene que
medirlo**: un check "el contenido entra en su caja", con **umbral explícito**, que **cuente
como falla** y nombre al culpable. Un check que *imprime* el problema pero no lo cuenta es
un gate verde con mentira.

### C14 · Cambiar la fuente rompe el modelo de medidas
**Síntoma:** todo estaba bien y, al cambiar la tipografía (o al corregir un `font-family`
que pisaba la fuente del proyecto), el contenido **se sale de su caja**: un número que
entra ya no entra.
**Causa:** el modelo de medidas estaba calibrado con la fuente **anterior**. Arial tiene
**dígitos tabulares** (todos miden lo mismo); Geist (y casi todas las fuentes
proporcionales) **no**: el «0» mide 0,6931 em y el «1» 0,4491. Un ancho de carácter
estimado con la fuente vieja queda corto (o largo) con la nueva.
**Arreglo:** recalibrar el modelo con las medidas **de la fuente que se usa** (medidas de
verdad, no de memoria) y **blindarlo con un test** que falle si el modelo usa un avance
menor al peor caso medido. Y medir el **efecto visual**: que el caso común no se encoja
de más (1 px menos en un número es el precio de que entre; 5 px menos es un bug).
**Clase hermana:** un `font-family` escrito a mano en el CSS global **pisa** la fuente que
el framework carga (el `font-sans` del tema): la app renderiza con la fuente que nadie
pidió y descarga archivos de fuente al pedo. La fuente se pone como **utilidad**, en el
markup.

### C15 · Un gancho de pruebas sin estilo: documentalo o limpialo
**Síntoma:** en el markup quedan clases que **no aplican ningún estilo** (o porque el
estilo se mudó a utilidades, o porque nacieron como ancla para los tests). Dos riesgos:
el lector cree que hay un estilo que no existe, y el test depende de un nombre que
nadie sabe por qué está.
**Regla:** si un nombre queda **sólo** para que lo selectionen los tests, tiene que
**decirse**: un `data-testid`, o un comentario que diga "ancla de pruebas" al lado. Si el
patrón ya existe en el proyecto, seguí el patrón y no inventes otro. Y si el test puede
seleccionar por algo más estable (id, texto, rol), **cambiá el test y borrá el gancho**:
los tests son tuyos, no un muro.

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

### D8 · La emulación móvil sólo aplica en el documento NUEVO
**Síntoma:** configurás el viewport del device, medís, y te da el ancho de la ventana real
(1019 px): la auditoría dice "todo bien" y no midió nada.
**Causa:** `Emulation.setDeviceMetricsOverride` (con `screenWidth`/`screenHeight` y
`mobile: true`) recién surte efecto en la **documento siguiente**: hay que aplicarlo y **después
navegar**. Medir antes de navegar da la ventana real.
**Regla:** tu auditoría tiene que **verificar el viewport antes de medir** y **fallar loudly**
si no es el pedido ("esperaba 375 y el navegador mide 1019"). Una auditoría que mide el
viewport equivocado sin avisar es peor que no tener auditoría.

### D9 · Los breakpoints se miden, no se suponen
**Síntoma:** el proyecto "usa responsive" y en el teléfono todo se rompe igual.
**Causa:** la app se construyó desktop-first y los breakpoints son un parche.
**Regla:** contá cuántos breakpoints hay (un grep de `sm:|md:|lg:` da la respuesta en un
segundo) y auditá **vista por vista y modal por modal** barriendo **un rango** de anchos de
device (320-1024 px), no tres teléfonos. Y pedí que el arreglo sea **fluido**: si el fix es un
`@media` por teléfono, la auditoría lo va a marcar en el ancho siguiente. Un gate de
responsive en la ronda es lo que lo convierte en regla y no en intención.

### D10 · Una auditoría que nunca falla no es una auditoría
**Síntoma:** el gate de responsive dice "ok" y el layout está roto (o al revés: el gate
falla por una regla que nadie pidió).
**Causa:** la auditoría se validó **contra un layout sano**: nunca se comprobó que detecte
una fuga real.
**Regla:** **rompé algo a propósito y exigí que el gate lo detecte** (un `whitespace-nowrap`,
un `w-[999px]`, un `min-width`). Si el gate sigue diciendo "ok", el gate está roto: es peor
que no tenerlo, porque da confianza falsa. Lo mismo con los **avisos**: una herramienta que
distingue "tap muerto" de "control alcanzable scrolleando" tiene que **probar esa
distinción** en los dos casos.
**Regla de la emulación:** verificá que la auditoría mide **el viewport que dice medir**
(fallo ruidoso si la emulación no aplicó) y que el comportamiento que mide (puntero grueso,
por ejemplo) esté **realmente emulado** — sin `setTouchEmulationEnabled`, un "teléfono"
sigue reportando `pointer: fine` y la regla de targets no se aplica.

### D11 · No escribas en la memoria persistente mientras otro agente escribe
**Síntoma:** un subagente muere con `database is locked` (o `SQLITE_BUSY`) justo al guardar
el cierre de su ronda; el trabajo queda hecho pero sin informe.
**Causa:** la memoria persistente es un **SQLite**, y dos escritores simultáneos se bloquean.
**Regla:** la memoria se escribe **al final de la ronda, una sola vez**. Si el orquestador
también escribe mientras el subagente trabaja, uno de los dos se bloquea. Cuando un subagente
muera por esto: **no lo des por perdido** — retomá su sesión (el árbol quedó intacto) y
pedile que cierre.
**Corolario:** en una ronda, el orquestador **no escribe en la memoria** hasta que el
subagente terminó.

### D12 · Un flag sin valor apaga el check EN SILENCIO
**Síntoma:** un gate que debería fallar da verde, y no hay error ni aviso.
**Causa:** un parámetro opcional sin valor → `NaN` → la comparación del check da `false`
para todos los casos → el check **nunca** dispara (y el runner sigue reportando `ok>0`).
**Regla:** todo umbral o flag de un gate tiene que **validarse al arrancar** (`Number.isFinite`
y un rango con sentido) y **fallar ruidosamente** si no tiene valor. Un gate que se
desapaga sin decir nada es peor que no tenerlo.
**Corolario:** el gate tiene que **medir su propio contrato**: ¿detecta una fuga real? ¿el
umbral se puede ablandar a voluntad? Probá el flag con un valor absurdo y exigí que se queje.

### D13 · Una auditoría que sólo mide una orientación no ve la mitad del problema
**Síntoma:** el gate barre 320→1024 y da verde; en landscape la app está rota.
**Causa:** el sweep es sólo portrait (la forma en que se escribe un layout), y el
landscape es donde el pie pegajoso y los paneles se estrujan.
**Regla:** el sweep tiene que incluir **las dos orientaciones** (portrait y landscape, con
las alturas de teléfono y tablet reales: 844×390, 667×375) y los modales medirse en las
tres. Si un bug aparece sólo en landscape y el gate no lo mira, el gate es decorativo.

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
