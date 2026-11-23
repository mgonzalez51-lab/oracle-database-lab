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
