# Lab 5 · Oracle DBA Workflow II: respuestas

Issue #9 · rama `chore/9-oracle-dba-workflow-ii` · evidencias en `docs/bitacora/lab5/evidencia/`

## Parte A: punto de partida

- La copia `lab4-final` ocupa 795 MB comprimida (el volumen tiene 6101 MB) y las sumas SHA-256 dan OK.
- En el paso 6 del backup sale «ninguno: el volumen contiene toda la base de datos». En la copia del Lab 3 había cinco datafiles fuera, así que esto demuestra que la reubicación del Lab 4 funcionó.

## Parte B: banco TiendaSur

- CLIENTE: 100 000 filas, 1517 bloques, R = 102 bytes, bfr = 66 (el enunciado da 1467 y 98: mis filas son 4 bytes más largas). Con la fórmula, ⌈100 000 / 66⌉ = 1516, así que cuadra.
- PEDIDO: 1 000 000 filas, 5320 bloques, bfr = 188, igual que el enunciado.
- Más allá del enunciado: la base tiene FORCE_LOGGING = YES, así que el `INSERT /*+ APPEND */` generó todo el redo: los archivados pasaron de 1168 a 1364 MB (+196 MB) en 9,5 s.
- **B1 → B.** Si el optimizador espera 25 000 filas y salen 20, es que no hay histograma: sin él supone 1/4 = 25 % por estado.
- **Reto B.** Con `ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE')` salen 5220 bloques con filas (mín. 2, media 191,6, máx. 200), frente a 5320 en las estadísticas. Los 100 que faltan son la cabecera, los bitmaps de ASSM y bloques bajo la HWM sin filas. Casi todos tienen 191-192 filas. No todos tienen las mismas porque la fila es de longitud variable (`importe`, `codigo_postal`) y el último bloque se quedó con 2.

## Parte C: anatomía de un índice

- IX_PED_CLIENTE: altura 3, 2216 hojas, fo real 370 y fo máximo 543, hojas al 90 %. Buscar por PK cuesta 4 lecturas (3 de índice + 1 de tabla) y 3 si es cubriente.
- En el volcado de la hoja de PK_CLIENTE, `row#0` tiene `data:(6): 00 00 03 1b 00 00` y la clave `c1 02`: es el bloque 0x31B = 795, ranura 0, el cliente 1. Son 6 bytes porque en BIGFILE no hace falta guardar el número de archivo.
- Más allá: las PK están llenas al 99,9 % y los índices creados con `CREATE INDEX`, al 90 %. Las PK se rellenan durante la carga con claves crecientes, mientras que CREATE INDEX respeta PCTFREE 10.
- Trampa que me encontré: `SET SERVEROUTPUT ON` hay que ponerlo después de `ALTER SESSION SET CONTAINER`, porque al cambiar de contenedor se pierde y el PL/SQL no muestra nada.
- **C1 → C (4).** BLEVEL 2 es altura 3, más 1 lectura de la tabla.
- **C2 → C (4).** 500² = 250 000 < 2 000 000, así que hacen falta 3 niveles de ramas más el de hojas.
- **Reto C.** Calculé altura 2 (30 B/entrada → 417 hojas, fo 543) y salió 3. Las entradas reales ocupan 35,9 B (501 hojas) y, al ser texto, la rama tiene 18,2 B por entrada, así que el fo baja a 441 < 501. PK_CLIENTE tiene fo 736 y altura 2. La altura depende también del tamaño de la clave. El mapa de PK_CLIENTE sale lleno (#) porque se cargó en orden; el de UX_CLI_EMAIL, al 90 % (=), porque se creó después.

## Parte D: tipos de índice

- Único 1486 → 3 (con ORA-00001 y ORA-03301); compuesto con SKIP SCAN 144 frente a 105; Q7 15 + SORT → 7 → 3 cubriente; funcional 1486 → 4; parcial 246 frente a 239, pero 54 hojas frente a 2933; bitmap 4073 → 528 (114 hojas frente a 1954); IOT 3 y hash 1, aunque la limpieza en hash lee 2770.
- **D1 → B.** **D2 → A y C** (el cubriente de Q7 ocupa 40 MB y la tabla 41,6 MB).
- **Reto D.** No haría cubriente IX_PED_FECHA para Q9: hoy cuesta 5 lecturas (3 de índice + 2 bloques de tabla) y como mucho ahorraría 2, a cambio de pasar de 22 MB a unos 42 MB (la tabla entera duplicada) y de encarecer cada INSERT.

## Parte E: factor de agrupamiento y punto de equilibrio

- CF de IX_PED_FECHA = 5220 (bloques con filas) y de IX_PED_CLIENTE = 999 041 (casi las filas). El cálculo a mano con LAG da lo mismo.
- **E1 → B.** Un CF malo con el 3 % es recorrido completo. Reconstruir el índice no cambia el CF, porque el CF depende de cómo está ordenada la tabla.
- **Reto E.** El índice con CF malo supera a la tabla en un ≈ 0,54 % (teoría 1/bfr = 0,53 %) porque visita un bloque por fila. El optimizador cambia antes, entre el 0,1 % y el 0,2 % (teoría 0,11 %), porque supone que la lectura aleatoria cuesta unas 5 veces más que la secuencial. El índice con CF bueno aguanta hasta un ≈ 66 % porque lee bloques consecutivos, y solo pierde porque además lee el propio índice (7875 frente a 5232 al 100 %).

![Curva del punto de equilibrio](lab5/img/lab5-curva-equilibrio.png)

## Parte F: sargabilidad

- Rota frente a reescrita: UPPER(email) 1486 → 4; fecha + 30 5285 → 321; cp = 30001 5232 → 106 (`filter(TO_NUMBER("CODIGO_POSTAL")=30001)`); OR 1486 → 6.
- Más allá: para `LIKE 'Gonz%'` el optimizador elige el índice y lee 2024 bloques, más que la tabla (1486). APELLIDOS no tiene histograma, así que no sabe que es un 2,1 % con CF malo.
- **F1 → B.** **F2 → A y C.**
- **Reto F: mi comentario de revisión en el PR**

  **issue (blocking):** `UPPER(apellidos) = 'GIL'` devuelve 0 filas de 100 000, porque `apellidos` guarda los dos apellidos (`'García Gil'`). Las 981 filas vienen todas del teléfono. ¿Querías los de segundo apellido Gil? Son 6121.

  **issue (blocking):** rompe la regla 1 (función sobre la columna en las dos ramas) y, por eso, la 5 (un OR solo usa índices si cada rama tiene el suyo). Medido: 1487 lecturas, y siguen siendo 1487 aunque cree índices en `telefono` y `apellidos`.

  **suggestion:** `WHERE telefono LIKE '600%' OR apellidos = 'Gil'` devuelve las mismas 981 filas en 722 lecturas (la mitad) con BITMAP OR. Pero esos dos índices no existen, así que habría que pasarlos antes por el protocolo de la Parte G.

  **note:** si es el segundo apellido (`LIKE '% Gil'`), son 7033 filas (7 %): el recorrido completo (1499) es el plan correcto. Para buscar bien por apellido habría que separar `apellido1` y `apellido2`.

## Parte G: protocolo de diseño de índices y V005

- Bloques modificados por fila (INSERT / UPDATE estado / UPDATE importe / DELETE): hoy, con 4 índices, 10,1 / 2 / 6 / 10,1; con la propuesta del compañero (9), 20,4 / 6 / 6 / 20,1; con V005 (5), 12,1 / 8,1 / 6 / 10,1. Se cumple INSERT ≈ 2 + 2 × índices (dato + undo, y hoja + undo por cada índice).
- El redo por INSERT pasa de 1323 B a 2669 B con la propuesta del compañero: el doble de redo, que acaba archivado.
- Protocolo: MONITORING USAGE marca sin uso IX_PED_CANAL, IX_PED_CLIENTE, IX_PED_FEC_CLI e IX_PED_IMPORTE. Estado y canal no son viables para igualdad. IX_PED_CLIENTE es prefijo de IX_PED_CLI_FEC. IX_PED_IMPORTE pasa a INVISIBLE y Q2 sigue en 328 lecturas.
- Más allá: la pregunta 2 marca IX_PED_ESTADO como «no viable» (25 % de media), pero Q12 lo usa con 147 lecturas, porque 'P' es el 2 % y esas filas están juntas al final de la tabla. Con datos sesgados la selectividad media engaña. Aun así, el índice parcial de V005 es mejor: 54 hojas frente a unas 2900 que habría que mantener en cada UPDATE de estado.
- V005 borra IX_PED_CLIENTE después de crear el cubriente, que también empieza por id_cliente. Si no, la clave ajena se quedaría sin índice y cada DELETE de un cliente bloquearía PEDIDO entera.
- **G1 → B** (INVISIBLE). **G2 → B** (unos 1000: 2 bloques × 500 INSERT/s).
- **Reto G: mi índice, IX_CLI_TELEFONO para Q5 (identificar a quien llama por email o teléfono).** Lo creé, lo medí y lo borré; la decisión va como V006 en la rama `feat/9-v006-ix-cli-telefono`, sin fusionar. (1) Necesidad: Q5 pasa de 1486 a 6 lecturas con BITMAP OR. (2) Viabilidad: 99 952 valores distintos, 0,001 % por valor. (3) Escritura: el INSERT en CLIENTE pasa de 10,2 a 12,2 bloques por fila (+2, como dice la fórmula) y de 1392 a 1627 B de redo. Las altas de clientes son mucho menos frecuentes que los pedidos, así que el coste es pequeño. (4) Redundancia: ningún índice de CLIENTE empieza por telefono. (5) Ciclo de vida: 3 MB, se crea ONLINE y se vigila con DBA_INDEX_USAGE; si no se usa, INVISIBLE y fuera. Mi conclusión es que sí compensa.

## Parte H: divisiones de hoja, patrón cola y remedios

- 200 000 inserciones: AZAR 595 divisiones (0 de 90/10), 596 hojas al 75,4 %; CRECIENTE 398 divisiones, todas 90/10, 399 hojas al 99,9 %; REVERSE 511 (0 de 90/10), 512 hojas al 77,9 %. Con claves al azar sale un 75 %, del orden del 69 % (ln 2) de la teoría: un índice real de 200 000 entradas se acerca, pero no llega a coincidir.
- El precio de REVERSE: el rango `k BETWEEN 1000 AND 1100` cuesta 4 lecturas con el índice normal y 866 con REVERSE, porque ya no puede usar el índice y hace recorrido completo.
- Patrón cola: tras 200 000 altas, 150 000 bajas de las más antiguas y 50 000 altas, IX_COLA tiene 425 hojas, 224 de ellas vacías, y 70 497 entradas borradas (41 %). «El siguiente mensaje» cuesta 226 lecturas frente a 2 en un índice sano.
- Remedios: COALESCE deja 201 hojas y 2 lecturas, pero mantiene 4 MB; SHRINK SPACE baja a 1,69 MB; REBUILD ONLINE deja 223 hojas (más que COALESCE, porque vuelve a aplicar PCTFREE 10, con hojas al 89,7 %).
- Más allá: los archivados han pasado de 1364 a 2928 MB desde la Parte B, y esta Parte sola ha añadido 586 MB en 18 s. Están en `dbs` sin FRA y sin límite, así que hay que resolverlo en la Parte L.
- **H1 → B** (COALESCE: en línea y barato). **H2 → A y C.**
- **Reto H:** pendiente de clase (el índice degradado lo crea el profesor; el diagnóstico irá como comentario en el Issue #9).
- **Punto de control, con mis cifras:** (1) buscar por PK cuesta 4 lecturas = altura 3 del índice + 1 bloque de tabla (Parte C). (2) IX_PED_CLIENTE pierde frente a la tabla al 1 % porque, con un CF de 999 041, cada fila es un bloque: 9920 lecturas frente a 5232 (Parte E). (3) Q3 no usaba el índice porque Oracle añadía `TO_NUMBER("CODIGO_POSTAL")`: 5232 lecturas, y 106 con '30001' (Parte F). (4) Cada índice suma unos 2 bloques por INSERT: 10,1 con 4 índices y 20,4 con 9 (Parte G). (5) La cola leía 226 bloques para 1 fila porque recorría 224 hojas vacías por la izquierda (Parte H).

## Parte I: SCN y checkpoints

- El SCN sube aunque nadie haga nada: 5 646 623 y 5 646 625 con 3 s de diferencia (procesos internos, MMON, jobs).
- Antes del checkpoint, academia01.dbf (CON_ID 3) tenía 5 643 405 y system01.dbf (raíz) 5 643 252. No fue por una operación de tablespace: el backup acababa de reiniciar la base y FREEPDB1 se abrió un poco después que la raíz, con su propio checkpoint. Tras `ALTER SYSTEM CHECKPOINT`, control file y cabeceras quedan en 5 646 633.
- **Punto de control.** (1) PDB$SEED (CON_ID 2) se queda en 2 098 101 porque está en solo lectura: nadie cambia sus bloques y el checkpoint no la toca. (2) Mi ACTUAL_REDO_BLKS es 309, no 33 024, porque el SHUTDOWN IMMEDIATE del backup hizo un checkpoint completo y el redo de las Partes B a H ya estaba cubierto. (3) Con una carga diez veces mayor crecería el redo pendiente y con él el MTTR; lo acota FAST_START_MTTR_TARGET (más bajo = checkpoints incrementales más frecuentes = más escritura en datafiles).
- **I1 → B.**
- **Reto I.** Tras el UPDATE de 20 000 filas sin checkpoint: ACTUAL_REDO_BLKS pasa de 12 a 3676 (unos 1,8 MB de redo) y RECOVERY_ESTIMATED_IOS de 11 a 354 (bloques sucios). El MTTR se queda en 2 s y a los 30 s no baja, porque con fast_start_mttr_target = 0 DBWn solo escribe cuando el redo pendiente se acerca a TARGET_REDO_BLKS (663 552 bloques, unos 324 MB). La relación: cuanto más redo pendiente y más bloques sucios, más redo hay que aplicar y más bloques leer en una recuperación de instancia, y por tanto más MTTR.
