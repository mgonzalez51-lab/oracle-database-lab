# Lab 4 — Oracle DBA Workflow I · Respuestas

Miguel Gonzalez Corvillo · mgonzalez51-lab · Issue #7

## Parte A — Punto de control

A mí no me salió ningún archivo FUERA en el paso 3 del backup (evidencia 00), los 26 salen "dentro". Al principio me extrañó porque los cinco datafiles de negocio están en `$ORACLE_HOME/dbs`, pero mirando el `ls -l` del final de la evidencia 01 vi que en mi imagen `dbs` es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs`, y como el script usa `readlink -f` los acaba encontrando dentro del volumen.

Oracle los creó ahí porque en V000 puse rutas relativas (`'academia01.dbf'`) y `db_create_file_dest` está vacío, así que sin OMF la ruta se resuelve contra `$ORACLE_HOME/dbs`.

## Parte A — Informe de diagnóstico

1. **Alto** · En V000 quedaron las contraseñas de los cinco `admin_*` y ya están en el historial de Git. Además el `08-aplicar-migraciones.sh` pasa `sys/<contraseña>` por la línea de comandos, o sea que se puede ver con `ps`.
2. **Medio** · Los datafiles de `TBS_ACADEMIA` a `TBS_FINTECH` (file# 16 a 20 en la evidencia 01) están en `dbconfig/FREE/dbs`. No se pierden si borro el contenedor, pero no están en `FREE/FREEPDB1`, que es donde se esperaría encontrarlos, y dependen de un enlace que la imagen podría cambiar en una actualización.
3. **Medio** · Esto no lo pedía el enunciado pero lo encontré revisando: la base está en ARCHIVELOG y no tiene FRA (`db_recovery_file_dest` vacío). Los archivados se van a `$ORACLE_HOME/dbs/arch` sin ningún límite, ya hay seis (`arch1_1` a `arch1_6`) y encima con extensión `.dbf`, que se pueden confundir con datafiles. `dbs` ya ocupa 1,4 GB.
4. **Bajo** · El contenedor sigue publicando el 8181 pero dentro no escucha nada, porque ORDS lo instalé en Linux y va por el 8080.
5. **Orden** · Empezaría por los datafiles (Parte C), porque la prueba de persistencia recrea el contenedor con el 05 v2 y de paso quito el 8181. Luego las contraseñas con V003 y el 08 v2, que no hace falta parar la base. Lo de los archivados lo dejo para el Lab 5, que es donde se configura la FRA.

## Parte B — Cuenta C##OPS_RO

Creé `C##OPS_RO` como usuario común (`CONTAINER = ALL`) y en la evidencia 02 sale con `COM=YES` y `OPEN` en `CDB$ROOT` y en `FREEPDB1`. `PDB$SEED` no aparece porque las vistas `CDB_` no la muestran, aunque la cuenta también existe ahí.

Para comprobar que de verdad solo puede mirar la probé con `ro.sh` (está al final de la evidencia 02). Desde la raíz ve los 16 datafiles de todos los contenedores, porque tiene `CONTAINER_DATA = ALL`, pero cuando intento un `CREATE TABLE` me da `ORA-01031: insufficient privileges`.

## Parte B — Reto: ¿darle el rol DBA?

Yo no se lo daría, por dos motivos:

1. Con DBA la cuenta puede hacer `DROP ANY TABLE`, `ALTER USER`, etc. Su contraseña la tendrían herramientas de monitorización o gente que solo quiere mirar, así que un despiste o que alguien la robe ya no se queda en "ha visto algo", sino que puede romper la base.
2. DBA trae `SELECT ANY TABLE`, o sea que podría leer los datos de negocio (los pacientes de Clínica o los movimientos de Fintech) cuando para monitorizar no le hace falta nada de eso. Además, con roles tan amplios nadie revisa luego qué puede hacer cada cuenta y los permisos se van acumulando.

Si necesitara leer el alert log le daría solo ese objeto: `GRANT SELECT ON sys.v_$diag_alert_ext TO c##ops_ro CONTAINER = ALL;`. El grant va sobre `V_$` porque `V$DIAG_ALERT_EXT` es un sinónimo público y el permiso se da sobre la vista real.

## Parte C — Reubicar los datafiles y prueba de persistencia

Moví los cinco datafiles de negocio con el método offline (`OFFLINE NORMAL`, copia con `cp -p`, `RENAME DATAFILE`, `ONLINE`), porque la versión Free no tiene el `MOVE DATAFILE` online. En la evidencia 03 se ve que los cinco acaban en `FREE/FREEPDB1` en `AVAILABLE` y con `MAX_MB 1024`, y que la segunda vez que lo ejecuto dice "Nada que reubicar". En el `ls` de después ya no queda ningún `*01.dbf` en `dbs`, solo los archivados, el SPFILE y el password file.

Lo importante es que `RENAME DATAFILE` no mueve nada, solo cambia la ruta que guarda el control file, por eso primero hay que copiar el archivo y el original no se borra hasta que el `ONLINE` funciona.

Después cambié el `05-crear-contenedor.sh` por la versión 2: ya no publica el 8181 y, como el volumen ya tiene la base, crea el contenedor sin pasar ninguna contraseña (antes el `ORACLE_PWD` se quedaba en el `docker inspect` cada vez). En la prueba de persistencia borré el contenedor y lo recreé: antes y después salen los mismos tablespaces y las mismas tablas, y `docker port` ya solo enseña el 1521. Todo tardó 15 s, la base estaba abierta a los 10 s. La hice después de reubicar a propósito, porque si algún archivo hubiera estado fuera del volumen el `docker rm` se lo habría llevado.

**P2:** B. En Standard Edition (y en Free) no existe el `MOVE DATAFILE` online, así que hay que poner el tablespace OFFLINE, copiar el archivo con el sistema operativo, hacer el `RENAME DATAFILE` y ponerlo ONLINE, que es justo lo que hace mi `03-reubicar-datafiles.sh`.

## Parte C — Reto: que no vuelva a pasar

Para que un `CREATE TABLESPACE` con ruta relativa o sin ruta no vuelva a acabar en `$ORACLE_HOME/dbs` activé OMF apuntando al volumen:

`ALTER SYSTEM SET db_create_file_dest = '/opt/oracle/oradata' SCOPE = BOTH;`

Lo hice en la raíz para que FREEPDB1 y cualquier PDB nueva lo hereden, y con `SCOPE = BOTH` para que se aplique ya y además quede en el SPFILE y no se pierda al reiniciar (en la evidencia 03-omf sale el mismo valor en `v$parameter` y en `v$spparameter`).

Para probarlo creé `tbs_x` sin cláusula `DATAFILE` y Oracle lo puso en `/opt/oracle/oradata/FREE/55E54F210F100828E0630B00580ADFD0/datafile/o1_mf_tbs_x_ohk5w8wq_.dbf`, o sea dentro del volumen, en una carpeta con el GUID de la PDB y con nombre generado por Oracle. Después lo borré con sus datafiles para no dejar basura.

Una cosa que no esperaba: el `MAX_MB` salió 33554432 (32 TB), porque en 26ai los tablespaces se crean BIGFILE por defecto y con OMF el autoextend no tiene límite. O sea que OMF arregla dónde se crea el archivo pero no cuánto puede crecer, así que en las migraciones seguiría poniendo `MAXSIZE`.

## Parte D — V003 (contraseñas) y V002 (datos de demostración)

Primero cambié el `08-aplicar-migraciones.sh` por la versión 2. La del Lab 3 cargaba el `.env` y montaba `sys/$ORACLE_PWD@localhost:1521/...`, así que la contraseña de SYS se podía ver con `ps` mientras se ejecutaba. La nueva usa `/ as sysdba` (autenticación del sistema operativo dentro del contenedor) y ya ni siquiera lee el `.env`.

Para las contraseñas de V000 no valía con borrarlas del archivo, porque V000 ya está aplicada y además siguen en el historial de Git. Lo que hice fue invalidarlas. Antes de aplicar V003 probé a entrar con la contraseña que hay en V000 y entré como `ADMIN_ACADEMIA` sin problema, o sea que cualquiera con acceso al repo podía hacerlo. Después de V003 los cinco `admin_*` quedan con `AUTHENTICATION_TYPE = NONE` y con la misma contraseña me da `ORA-01017` (evidencia 04). Siguen en `OPEN` porque no están bloqueadas, simplemente no tienen forma de iniciar sesión: son dueñas de sus tablas y ya está.

V002 cargó 20000 estudiantes, 40 asignaturas y 60000 matrículas, y la fila 101 sale `00000101X` y `ACTIVO`. La segunda vez que la ejecuté dijo que ya estaba aplicada y no insertó nada, que es lo que tiene que pasar para no duplicar datos.

**P-D1:** C. `NO AUTHENTICATION` quita cualquier forma de iniciar sesión, aunque alguien sepa la contraseña antigua. `ACCOUNT LOCK` se puede desbloquear y la contraseña sigue existiendo, `PASSWORD EXPIRE` deja entrar para cambiarla y quitar `CREATE SESSION` se puede volver a conceder (o le puede llegar por un rol).

## Parte E — Instancia y base de datos, arranque por etapas y alert log

Con `ro.sh` (evidencia 05) se ve muy claro qué es de cada uno. De la instancia: `HOST_NAME = 459c04bb7fae`, que es el ID del contenedor nuevo de la Parte C (en el diagnóstico de la Parte A era `e3636d59a527`), y `ARRANCADA = 2026-11-14 17:13:41`, que es cuando lo recreé. De la base: `DBID = 1509902213` y `CREADA = 2026-07-05`, que no han cambiado aunque haya tirado el contenedor. El DBID además es el mismo número que el autobackup `c-1509902213-...` que vi en `dbs`.

Desde Linux salen 56-60 procesos `db_*_FREE` (en 26ai ya no se llaman `ora_*`), el `tnslsnr` y, mientras tenía una sesión abierta por red, un `oracleFREE (LOCAL=NO)`, que es su proceso servidor dedicado. Me costó verlo porque al principio lanzaba la sesión y el script en la misma terminal y cuando el script miraba la sesión ya se había cerrado. Lo hice dejando la sesión en segundo plano.

**Punto de control (arranque por etapas, evidencia 06):**

- **ORA-01507 en NOMOUNT:** la instancia ya está levantada (SGA de 1603398928 bytes y procesos) y `v$parameter` responde porque los parámetros salen del SPFILE que ya está en memoria, pero `v$database` necesita el control file y todavía no se ha abierto.
- **ORA-01219 en MOUNT:** ya están abiertos los control files, así que `v$database` y `v$datafile` funcionan (16 datafiles conocidos), pero `dba_tables` es una vista del diccionario y el diccionario está en el tablespace SYSTEM, que es un datafile que sigue cerrado. En MOUNT solo valen las vistas fijas (`V$`).
- En OPEN FREEPDB1 se abrió sola en READ WRITE porque tiene el estado guardado (`dba_pdb_saved_states` la muestra en `OPEN`).

**P3:** A y C. `STARTUP_TIME` es de la instancia y cambia en cada arranque (a mí cambió al recrear el contenedor), y `CREATED` es de la base, cuándo se creó. El DBID no cambia al recrear el contenedor: el mío sigue siendo 1509902213.

**P4:** A y C. En NOMOUNT ya se puede consultar `v$parameter` porque sale de la memoria, y se puede recrear el control file con `CREATE CONTROLFILE` porque justo es la etapa en la que todavía no se ha leído. Para `dba_users` hace falta OPEN y para ARCHIVELOG o renombrar SYSTEM hace falta MOUNT.

**P5:** B. `ALTER DATABASE ARCHIVELOG` cambia el control file y necesita que los datafiles estén cerrados, o sea MOUNT.

## Parte E — Reto: el parte del reinicio

Sacado del alert log (evidencia 06, la tabla con las horas):

- **Parada pedida:** 2026-11-14 a las 17:40:24 UTC (18:40 en hora de Madrid), `SHUTDOWN IMMEDIATE` lanzado por sqlplus.
- **Cuánto tardó:** la parada terminó a las 17:40:27 (2,3 s) y la base estaba abierta a las 17:40:30, así que unos 5 s en total.
- **Recuperación de instancia:** no hubo. Solo sale el mensaje `Crash Recovery excluding pdb ... which was cleanly closed`, que es informativo, pero ninguna línea de `Beginning crash recovery`. Tiene sentido porque fue un `SHUTDOWN IMMEDIATE` y la base cerró limpia.
- **Errores:**
  - `ORA-00800 [Set Priority Failed] [VKTM]/[LGWR]` → **conocido**. El contenedor no deja a Oracle subir la prioridad de esos procesos, la base funciona igual.
  - `ORA-959` en `DROP TABLESPACE IF EXISTS tbs_x` → **conocido**. Lo provoqué yo en el reto de OMF: el `IF EXISTS` lanza el error por dentro y lo silencia, pero queda en el alert log.
  - `ORA-07427 / ORA-27300 / ORA-27303: cannot change directory to dbs` → **a investigar (prioridad baja)**. Salió solo en el primer arranque del contenedor recién recreado (17:13:40) y no se repitió en el reinicio de las 17:40. Creo que es porque el enlace `dbs` de la imagen todavía no existía en ese momento, pero no lo he podido confirmar, así que no lo doy por conocido.

## Parte F — Parámetros: SPFILE, SCOPE y PDB

Mi instancia arrancó con SPFILE (`/opt/oracle/product/26ai/dbhomeFree/dbs/spfileFREE.ora`) y usa ASMM, no AMM: `memory_size = 0`, `sga_target = 1536M` y `pga_aggregate_target = 512M`. En total tiene 564 parámetros, 19 que no están por defecto y 134 estáticos (evidencia 07, lectura).

Un detalle que me sirvió para entender `ISMODIFIED`: `db_create_file_dest` (el del reto de OMF) sale con `ISDEFAULT = FALSE` pero `ISMODIFIED = FALSE`. Es porque lo cambié antes del reinicio de la Parte E, así que en este arranque ya venía del SPFILE y nadie lo ha tocado desde entonces. También vi que en el SPFILE no hay nada de ARCHIVELOG: eso no es un parámetro, está en el control file.

En los cambios (evidencia 07, cambios) se ven bien los alcances: con `SCOPE = MEMORY` `open_cursors` quedó en 400 en memoria y 300 en el SPFILE, y con `SCOPE = BOTH` en 500 en los dos sitios. `db_files` es estático: en memoria da `ORA-02095` y en el SPFILE se queda pendiente (200 en memoria y 300 en el SPFILE) hasta el próximo arranque. Lo deshice con `RESET` y la línea desapareció.

Lo de `processes` me pareció lo más curioso: `v$parameter` lo marca como `IMMEDIATE`, pero al cambiarlo en memoria da `ORA-02097` + `ORA-02095`. La tabla de procesos se dimensiona en la SGA al arrancar y no se puede ampliar en caliente, así que en la práctica solo se cambia con `SCOPE = SPFILE` y reinicio.

Al final guardé dos PFILE en `evidencia/config`: `initFREE_lab4.ora` (sacado del SPFILE, 33 líneas) e `initFREE_lab4_memoria.ora` (de la memoria, 123 líneas). La diferencia son parámetros que la instancia usa pero que nadie ha escrito, como `log_buffer` u `optimizer_mode`. Comprobé que después de las pruebas no quedó nada cambiado: `open_cursors=300`, `processes=200` y ninguna línea de `db_files`.

**P6:** B. Si la instancia arrancó con SPFILE y no pones `SCOPE`, por defecto es `BOTH`: cambia en memoria y en el SPFILE.

**P7:** C. `PROCESSES` es de instancia y no se puede tocar desde una PDB, da `ORA-65040`, que es justo lo que me salió en el bloque 5.

**P8:** A y C. Con `STARTUP PFILE=` arrancas con un PFILE bueno saltándote el SPFILE roto, y con `CREATE SPFILE FROM PFILE=` lo regeneras para los siguientes arranques. Las demás no sirven si la instancia ni siquiera arranca.

## Parte F — Reto: petición de cambio de open_cursors

**Petición:** desarrollo quiere subir `open_cursors` a 1000 porque les sale `ORA-01000: maximum open cursors exceeded`.

- **Valor actual:** 300, escrito en el SPFILE (`*.open_cursors=300`, línea 28 de `initFREE_lab4.ora`) y aplicado en memoria. Es por sesión, no total de la instancia.
- **Antes de tocar nada:** miraría qué sesión abre tantos cursores con `v$open_cursor` y la estadística `opened cursors current` de `v$sesstat`. Un `ORA-01000` casi siempre es porque la aplicación abre cursores y no los cierra, y si es eso subir el límite solo hace que falle más tarde. Lo primero sería pedirles que lo revisen.
- **Valor propuesto:** si después de eso de verdad necesitan más, no iría directamente a 1000 sino a 500, que es lo que se justifique con lo medido.
- **SCOPE:** `ALTER SYSTEM SET open_cursors = 500 COMMENT = 'CR-xxx ORA-01000 app' SCOPE = BOTH;`. Es dinámico, así que no hace falta reiniciar, y con `BOTH` no se pierde en el próximo arranque. El comentario deja apuntado el ticket en el propio SPFILE.
- **Prueba:** que la aplicación repita lo que le fallaba y seguir `opened cursors current` un rato para ver si se estabiliza o sigue subiendo (si sigue subiendo es una fuga).
- **Rollback:** `ALTER SYSTEM SET open_cursors = 300 SCOPE = BOTH;`, también sin reiniciar.
- **Evidencia:** la consulta de antes y la de después, y un PFILE nuevo en `evidencia/config` para que el cambio se vea en el `git diff`.

## Parte G — Memoria: SGA, Buffer Cache, análisis y PGA

**Cómo está repartida la memoria (evidencia 08, memoria).** Uso ASMM: `memory_target = 0`, `sga_target = 1536M` y `pga_aggregate_target = 512M`. Como `db_cache_size` y `shared_pool_size` están a 0, ASMM reparte solo sin ningún mínimo. Las cifras cuadran con las que imprimió el `STARTUP NOMOUNT` de la Parte E: los 1008 MB de *Database Buffers* son el buffer cache (928 MB) más el Shared IO Pool (80 MB), y los 512 MB de *Variable Size* son la shared pool (480), la large pool (16) y 16 MB libres. El asesor de la SGA sale plano (mismo tiempo y mismas lecturas estimadas de 768 MB a 3 GB), o sea que con la carga que tengo ahora no ganaría nada subiendo `sga_target`. En la PGA, entre los procesos que más usan salen ARC0-ARC3, que existen porque mi base está en ARCHIVELOG.

**Punto de control: el experimento de la caché (evidencia 08, caché).** `ACA_ESTUDIANTES` tiene 20000 filas en 244 bloques.

| | Lógicas | Físicas | Acierto (1 − físicas/lógicas) |
|---|---|---|---|
| Ronda 1 (caché fría) | 357 | 262 | 26,6 % |
| Ronda 2 (caché caliente) | 247 | 0 | 100 % |

- Las lecturas lógicas no bajan en la ronda 2 porque toda lectura física acaba siendo también lógica: el bloque se trae del disco al buffer cache y desde ahí se lee. Lo que cambia es que en la ronda 2 ya no hace falta ir a disco.
- A mí la ronda 1 me salió con 110 lógicas y 17 físicas más que en el enunciado. Creo que es porque el `FLUSH BUFFER_CACHE` también tiró los bloques del diccionario, y en la primera ejecución Oracle tuvo que releerlos de SYSTEM con consultas recursivas. En la ronda 2 ya estaban en memoria y sale exactamente 247 / 0.
- En `v$bh` quedan 245 bloques de la tabla para 244 de datos: el que sobra es la cabecera del segmento.
- El `FLUSH BUFFER_CACHE` solo lo usaría en un laboratorio para medir. En producción vacía la caché de toda la instancia y todas las consultas de todo el mundo irían a disco a la vez.

**Literales frente a variables de enlace (evidencia 08, parse).** Con literales salieron 1008 análisis duros, 530 ms de CPU solo analizando y 570 ms en total; con `:id`, 1 análisis y 10 ms. Es 57 veces más lento para el mismo resultado. En `V$SQL` la versión con literales dejó 854 cursores y 31791 KB de shared pool, frente a 1 cursor y 39 KB con la variable de enlace. Los análisis de más (1049 en total) son recursivos, consultas internas al diccionario. Con la variable de enlace sale 1 análisis y no 1000 blandos porque PL/SQL deja el cursor abierto entre vueltas del bucle.

**Punto de control: la PGA (evidencia 08, parse).** La ordenación de las 60000 matrículas necesitaba unos 2,6 MB. Con la PGA automática los tuvo: `OPTIMAL`, nada en TEMP y 10 ms. Con 64 KB Oracle escribió 3072 KB en TEMP y los releyó seis veces (`6 PASSES`), 220 ms, 22 veces más, y eso con una tabla pequeña. En la instancia el `cache hit percentage` de la PGA bajó del 100 % al 88,5 % y el histograma marca 2 ejecuciones de varias pasadas, que son las de mi prueba de 64 KB. `maximum PGA allocated` (465,5 MB) está cerca del objetivo de 512 MB sin error, porque el objetivo no es un límite; el límite de verdad es `pga_aggregate_limit` (2G).

**P9:** B. Con `MEMORY_TARGET = 0` y `SGA_TARGET` fijado es ASMM, y si además pones `DB_CACHE_SIZE` ese valor pasa a ser un mínimo: el buffer cache puede crecer pero no bajar de 512 MB.

**P10:** A y D. En servidor dedicado, el área de ordenación y la memoria de la sesión van en la PGA del proceso servidor. La shared pool, el log buffer y el buffer cache son de la SGA.

**P-G1:** B. Lo definitivo es cambiar la aplicación para usar variables de enlace. Agrandar la shared pool o hacer `FLUSH` solo esconde el problema, y `CURSOR_SHARING = FORCE` es un parche que afecta a todas las sentencias y el optimizador deja de ver los valores reales.

**P-G2:** B. `6 PASSES` quiere decir que el área de trabajo no cupo en la PGA y Oracle tuvo que releer seis veces sus datos desde TEMP, que es justo lo que me salió con los 64 KB.

## Parte G — Reto: encontrar a los culpables

Guardé la consulta en `scripts/lab4/08-reto-literales.sql`. Agrupa `V$SQL` por `force_matching_signature`, que es la misma para sentencias que solo cambian en un literal, y saca las que tienen más de 50 cursores. La ejecuto con `C##OPS_RO` desde la raíz, porque para buscar el problema solo hace falta mirar, y con `CONTAINER_DATA = ALL` ve también los cursores de FREEPDB1.

Salió una sola firma, la de `SELECT /* lab4_literal */ COUNT(*) FROM admin_academia.aca_estudiantes WHERE estudiante_id = ...`, en `CON_ID 3` (FREEPDB1), con 740 cursores, 740 ejecuciones y 27362 KB. Lo que más me llamó la atención es que un minuto antes `08-parse-y-pga` había contado 854 cursores: en ese rato la shared pool ya había echado 114. Eso es lo que hacen los literales en una base real, ocupan memoria y van echando cursores útiles de otras sentencias.

## Parte H — Procesos de background y procesos servidor

En `v$process` (evidencia 09) salen 86 procesos Oracle de background pero solo 53 procesos Linux distintos, así que 33 de esos "procesos" en realidad son hilos dentro de otros procesos. Los de servidor sí son 6 y 6, uno por uno. Están todos los obligatorios con su SPID (PMON 2266, LREG 2330, SMON 2322, DBW0 2314, LGWR 2318, CKPT 2320, MMON 2338...) y además `PROCESOS_ARCN = 4`, que son ARC0-ARC3, porque mi base está en ARCHIVELOG (el enunciado esperaba 0). También aparecen sesiones J000-J002, que son esclavos de la cola de jobs que coordina CJQ0.

**Pregunta 15: el SPID de LGWR y el PID de Linux.** Oracle dice que LGWR es el SPID 2318 y leyendo `/proc` dentro del contenedor el proceso 2318 es justo `db_lgwr_FREE`. En cambio `docker top` lo enseña con el PID 12762. Es el mismo proceso, pero el contenedor tiene su propio espacio de nombres de PID: Oracle guarda el PID que ve dentro y `docker top` enseña el del anfitrión. Por eso para cruzarlos hay que mirar desde dentro.

Otra cosa que comprobé es que la columna RSS no se puede sumar: cada proceso enseña entre 84 y 269 MB, pero casi todo es la SGA compartida que sale repetida en cada uno. Sumando los 59 saldrían más de 5 GB en un contenedor que usa unos 2 GB. Para la memoria real hay que ir a `v$sga` y `v$pgastat` como en la Parte G.

**P11:** C. El `COMMIT` solo espera a que LGWR escriba el redo en disco (write-ahead logging). Los bloques de datos los escribe DBWn más tarde, cuando haya checkpoint o falten buffers libres.

**P12:** B y D. PMON y SMON son obligatorios en cualquier instancia. ARC0 solo existe en ARCHIVELOG (yo lo tengo porque mi base lo está), RECO depende de transacciones distribuidas y CJQ0 de la cola de jobs.

## Parte H — Reto: la sesión que más consume

Lancé como SYSDBA (`docker exec ... sqlplus / as sysdba`) un producto cartesiano sobre `aca_matriculas` con la etiqueta `lab4_reto_h` y, mientras corría, lo busqué con `C##OPS_RO` usando `scripts/lab4/09-reto-sesion.sql`, que cruza `v$session` con `v$process` y `v$sql` para las sesiones de usuario activas ordenadas por PGA:

- **SID:** 46 (serial 31858), usuario `SYS`.
- **SPID:** 4675, y en `/proc` el 4675 es `oracleFREE (DESCRIPTION=(LOCAL=YES)(ADDRESS=(PROTOCOL=beq)))`. `LOCAL=YES` y `beq` es porque entró con `docker exec`, sin pasar por el listener, al revés que la sesión `LOCAL=NO` de la Parte E.
- **PGA:** 3,3 MB usados y 3,7 MB asignados.

La consulta contó 1799940000 filas en 28,94 s. La primera vez la hice con `< 3000` y tardó 2,9 s, así que acabó antes de que SQLcl llegara a conectarse y no la vi; la tuve que hacer diez veces más larga.

Lo que me llamó la atención es que por PGA la sesión que más tenía no era la mía sino el job J000 (16,3 MB). Mi consulta es casi todo CPU, porque es un `COUNT(*)` de un producto cartesiano y apenas necesita memoria. O sea que "la que más consume" depende de lo que mires: para la PGA vale `v$process`, pero para la CPU habría que añadir la estadística `CPU used by this session` de `v$sesstat`.

## Parte I — Navegar por los contenedores: qué ve cada usuario y por qué

**Punto de control (evidencia 10, qué ve cada usuario).**

- En `V$LOG` sale una fila con `CON_ID 0` porque el redo es de toda la CDB: hay una sola instancia y un solo juego de redo logs para la raíz y todas las PDB, así que no pertenece a ningún contenedor concreto.
- `C##LAB4_AUDITOR` desde la raíz solo ve 5 tablespaces (los de `CON_ID 1`) y las sesiones de `CON_ID 0` y 1, ninguna de FREEPDB1. Lo cambiaría `ALTER USER c##lab4_auditor SET CONTAINER_DATA = ALL CONTAINER = CURRENT;`, que es justo lo que tiene `C##OPS_RO` y por eso en la sección 6 solo aparece él.
- Con `READ ANY TABLE ON SCHEMA admin_academia` `lab4_analista` pudo leer las 3 tablas de Academia y los 20000 estudiantes, pero `admin_clinica.cli_pacientes` siguió dando `ORA-00942` (antes comprobé que la tabla existe, para que el error no fuera por eso). Con `SELECT ANY TABLE` habría podido leer las tablas de todos los esquemas, también los datos de Clínica y Fintech.

**Pregunta 16:** SYS ve 16 datafiles desde la raíz (4 de `CDB$ROOT`, 3 de `PDB$SEED` y 9 de FREEPDB1) y solo 9 desde FREEPDB1, porque dentro de una PDB las vistas solo enseñan lo de ese contenedor.

**Pregunta 17:** `lab4_analista` recibe `ORA-00942` y no "privilegios insuficientes" porque Oracle no te dice si existe algo que no puedes ver. Para él `DBA_TABLES` simplemente no existe. En cambio, cuando el objeto sí lo ve pero le falta la acción, 23ai es explícito: en el `UPDATE` me dio `ORA-41900: missing UPDATE privilege`.

**Pregunta 18:** los dos son comunes y tienen `CREATE SESSION`, `SET CONTAINER` y `SELECT_CATALOG_ROLE` con `CONTAINER = ALL`, pero `C##OPS_RO` además tiene `CONTAINER_DATA = ALL`. Los igualaría `ALTER USER c##lab4_auditor SET CONTAINER_DATA = ALL CONTAINER = CURRENT;`.

**Pregunta 19:** `GRANT READ ANY TABLE ON SCHEMA` da acceso a todo el esquema de una vez, incluidas las tablas que se creen después, y no hace falta ir tabla por tabla. El riesgo es justo ese: si mañana alguien crea en ese esquema una tabla con datos sensibles, el usuario también la va a poder leer sin que nadie se lo haya dado expresamente.

**Pregunta 20:** en mi base `COMMON_USER_PREFIX` vale `C##`, así que en el bloque 3a crear `lab4_local` en la raíz dio `ORA-65096`. En el enunciado salió vacío porque usaron otra imagen y el usuario se creó como común.

En `10-diccionario` también se ve que `DBA_TABLESPACES` desde la raíz da 5 y `CDB_TABLESPACES` 15 (5 de la raíz y 10 de FREEPDB1), y que las `V$` se apoyan en 1591 tablas `X$` en memoria: la definición de `GV$LOG` sale de `x$kccle` y `x$kccrt`, que son del control file, y por eso `V$LOG` ya funciona en MOUNT.

En el ciclo de vida creé `PDB_LAB4` desde la semilla (pasó de `MOUNTED` a `READ WRITE` con sus 3 datafiles en `FREE/PDB_LAB4/` y el servicio `pdb_lab4`), al intentar borrarla abierta dio `ORA-65025` y después de cerrarla se borró con sus archivos. Aunque tengo OMF activado, los archivos fueron a `PDB_LAB4/` porque el script usa `FILE_NAME_CONVERT`, que tiene prioridad.

**P13:** B. Dentro de FREEPDB1 `V$DATAFILE` solo enseña los de esa PDB, `CON_ID 3`. Lo comprobé: 9 datafiles y solo `CON_ID 3`.

**P14:** B. Lo que le falta es `CONTAINER_DATA = ALL`. `SET CONTAINER` ya lo tiene y solo sirve para entrar en la PDB, no para verla desde la raíz.

**P15:** A y D. El privilegio de esquema vale también para las tablas que se creen después y no da acceso a otros esquemas. No permite `UPDATE` (me dio `ORA-41900`) y no hace falta que el usuario sea común: `lab4_analista` era local.

## Parte I — Reto: acceso para una auditora externa

Es solo diseño, no lo ejecuto.

- **Local, en FREEPDB1.** Los datos de Clínica solo están en FREEPDB1, así que no tiene sentido un usuario común que exista en todos los contenedores. Además así no puede hacer `SET CONTAINER` a ningún sitio (en I.2 `lab4_analista` no pudo saltar a la raíz).
  `CREATE USER aud_clinica IDENTIFIED BY "<temporal, se le da por otro canal>" PASSWORD EXPIRE;` (con `PASSWORD EXPIRE` tiene que cambiarla al entrar la primera vez y la que le damos deja de valer).
- **Grant mínimo:**
  `GRANT CREATE SESSION TO aud_clinica;`
  `GRANT READ ANY TABLE ON SCHEMA admin_clinica TO aud_clinica;`
  Uso `READ` y no `SELECT` porque `READ` no deja hacer `SELECT ... FOR UPDATE`, así que ni siquiera puede bloquear filas. En I.2 se vio que con esto puede leer el esquema entero pero no otros (`ORA-00942`) ni modificar (`ORA-41900`).
- **El último día:**
  `REVOKE READ ANY TABLE ON SCHEMA admin_clinica FROM aud_clinica;`
  `ALTER USER aud_clinica ACCOUNT LOCK;`
  Bloqueo la cuenta en vez de borrarla para que su rastro de auditoría siga asociado a un usuario existente. Si la política lo permite, más adelante se borraría con `DROP USER aud_clinica;`.

## Parte J — Autopsia de los archivos de la base de datos

Primero le di a `C##OPS_RO` solo lo que le faltaba para leer el alert log desde SQL: `GRANT SELECT ON sys.v_$diag_alert_ext TO c##ops_ro CONTAINER = ALL;` (evidencia 11, ampliar). Es el mismo grant que puse en el reto de la Parte B, en vez de darle un rol amplio.

El inventario (evidencia 11, archivos) sale así: 16 datafiles (4119 MB), 3 tempfiles (60 MB), 2 control files (36 MB) y 3 grupos de redo online de 200 MB con un solo miembro cada uno. Además hay 6 redo archivados (856 MB), que son relacionados, no parte de la base. Los tamaños desde Linux cuadran con un bloque de más: un datafile de 100 MB ocupa 104865792 bytes, que son 100 × 1048576 + 8192 (el bloque 0, la cabecera), y el redo de 200 MB ocupa 209715712, o sea 200 MB + 512, porque el bloque del redo es de 512 bytes.

**Hallazgo: el ADR no está en el volumen.** La comprobación del script dice que `/opt/oracle/diag` vive en la capa del contenedor, y lo pude confirmar con fechas. En la tabla de reinicios de la Parte E el alert log salta del 5 de julio al 14 de noviembre a las 17:13, cuando recreé el contenedor. Falta el arranque del 13 de noviembre a las 18:44 (el del backup de la Parte A, que sí sale en `v$instance`) y todo el Lab 3. Las entradas de julio no sobrevivieron: vienen dentro de la propia imagen, porque la base se creó al construirla (`CREADA 2026-07-05`). O sea, al recrear el contenedor no perdí datos pero sí la historia del alert log, que es justo lo que hace falta para analizar un incidente. Lo apunto para la autopsia de la Parte N.

**Punto de control.**

- El password file sale como relacionado porque no tiene datos de la base, solo quién puede entrar como SYSDBA, SYSOPER... por red (en mi caso solo `SYS`, según `v$pwfile_users`). Si se pierde, la base sigue funcionando y se puede entrar con `/ as sysdba` desde la propia máquina; se vuelve a crear con `orapwd`.
- En mi imagen no son enlaces sueltos: es la carpeta `$ORACLE_HOME/dbs` entera la que apunta a `/opt/oracle/oradata/dbconfig/FREE/dbs`, dentro del volumen. Lo que se gana es que el SPFILE y el password file sobreviven al recrear el contenedor y entran en la copia del volumen (por eso en la Parte A la copia salió con 0 archivos fuera).
- TEMP no se respalda porque solo guarda datos de trabajo de las sesiones (ordenaciones, hash) que no valen nada después: si se pierde, se crea un tempfile vacío y listo. Por eso `v$tempfile` sale aparte y el resumen lo marca como "no se copia".

**P16:** B y D. La base son los datafiles, los control files y los redo online (y los tempfiles). El password file, el SPFILE y el alert log son archivos relacionados.

**P17:** C. Si se pierde el disco con los dos control files y el único miembro de cada grupo de redo, y además está en NOARCHIVELOG, no hay redo con el que recuperar: solo se puede restaurar la última copia completa y se pierde todo lo que se hizo después. Por eso hay que multiplexar en discos distintos.

## Parte J — Reto: plan de copia a partir del inventario

Una copia en frío completa sería: datafiles 4119 MB + control files 36 MB + redo online 600 MB + SPFILE y password file (unos pocos KB), o sea unos **4755 MB (≈ 4,6 GB)** sin comprimir. Los tempfiles no hacen falta. Mi copia real de la Parte A pesó 603 MB porque iba comprimida con gzip y la mayoría de los bloques de los datafiles están vacíos.

Con RMAN sobrarían:

- los **redo online** (600 MB): RMAN no los copia, hace una copia que se recupera con el redo archivado;
- el **segundo control file**: es la misma información multiplexada, basta con un autobackup del control file;
- los **tempfiles**, que tampoco entran en la copia en frío.

Además RMAN no copia los bloques que nunca se han usado, así que la copia saldría bastante más pequeña que esos 4,6 GB, y se podría hacer con la base abierta porque estoy en ARCHIVELOG.

## Parte K — Anatomía de una página: del tablespace al byte

`TBS_ACADEMIA` es BIGFILE, con gestión local, AUTOALLOCATE y ASSM, y bloques de 8192. `ACA_ESTUDIANTES` tiene 16 extensiones de 64 KB y luego una de 1 MB, que es como reparte AUTOALLOCATE (evidencia 12, bloque).

**El ROWID de la fila 101.** `AAAR2lAAAAAAAMPAAF` se divide en objeto, archivo, bloque y fila (base 64 con A=0 … Z=25, a=26 … z=51, 0=52 … 9=61):

| Trozo | Caracteres | Cálculo | Valor | Lo confirma |
|---|---|---|---|---|
| Objeto | `AAAR2l` | 17·64² + 54·64 + 37 | 73125 | `DATA_OBJECT_ID` de `ACA_ESTUDIANTES` |
| Archivo | `AAA` | 0 | 0 | En BIGFILE esos bits son parte del bloque |
| Bloque | `AAAAMP` | 12·64 + 15 | 783 | El volcado del bloque 783 |
| Fila | `AAF` | 5 | 5 | `tab 0, row 5` en el volcado |

El archivo real es el 16 (`academia01.dbf`), que se saca con `ROWID_TO_ABSOLUTE_FNO`; `RELATIVE_FNO` sale 1024, que en BIGFILE no es un número de archivo de verdad.

**La fila por dentro.** `DUMP()` enseña que el `101` se guarda como `c2 02 02` (NUMBER en base 100: 0xc2 indica dos "dígitos", y cada dígito lleva +1, o sea 1·100 + 1), el DNI y los textos en ASCII (`30` es el carácter `0`) y la fecha como TIMESTAMP de 11 bytes. La fila ocupa 78 bytes en el bloque (`tl: 78`): 68 de datos (la suma de `VSIZE`), 7 bytes de longitud, uno por columna (`cc: 7`), y 3 de cabecera (flag, lock y número de columnas). En el volcado también se lee en ASCII `Apellido101` y `est101@alu.ucam.edu`.

**Cómo de llenos están.** 230 bloques llenos, 1 con 25-50 % libre y 13 casi vacíos, en total 244, los mismos bloques que leyó el recorrido completo de la Parte G. Los 13 casi vacíos son el final del segmento: espacio ya asignado que aún no se ha llenado.

**Punto de control.**

- `avsp = fseo − fsbo`: 0x427 − 0xc6 = 0x361, en decimal 1063 − 198 = 865 bytes libres. Con `tsiz` = 0x1f98 = 8088 bytes útiles, el `PCTFREE 10` reserva 809. Otra fila de 78 bytes más su ranura de 2 dejaría 785, por debajo de 809, por eso el bloque se quedó en 90 filas.
- La fecha de la fila 101 sale de `78 7e 0b 0e 12 18 13`: siglo 120−100 = 20, año 126−100 = 26, mes 11, día 14, hora 18−1 = 17, minuto 24−1 = 23 y segundo 19−1 = 18, o sea **2026-11-14 17:23:18**, y `30 59 bf 20` son 811188000 nanosegundos. Es justo el momento en que apliqué V002 (su spool se llama `20261114T172318Z_04-V002...`).
- La ranura 1 de la ITL tiene `--U-` y `Lck 90`: la transacción de V002 que insertó las 90 filas está confirmada pero el bloque no se ha limpiado (limpieza diferida). Si ahora un `UPDATE` cambiara la fila 101 usaría la ranura 2, que está libre, y al tocar el bloque Oracle comprobaría que la transacción de la ranura 1 ya está confirmada y le pondría el `Lck` a 0.

**P18:** B. Sin el segundo argumento `ROWID_BLOCK_NUMBER` da por hecho que el tablespace es SMALLFILE y reparte los bits entre archivo relativo y bloque; en BIGFILE esos bits son todos del bloque y hay que pasarle `'BIGFILE'`, como hace el script.

**P19:** A y B. Un bloque deja de aceptar `INSERT` cuando su espacio libre baja del 10 %, y ese 10 % se reserva para que las filas que ya están puedan crecer con `UPDATE` (lo vi con los 809 bytes del bloque 783). No es solo para la ITL, sí afecta a tablas y una fila puede migrar igualmente si crece más de lo que queda libre.

## Parte K — Reto: abrir otro bloque

Hice una copia del script para el estudiante 19500 (`scripts/lab4/12-reto-bloque.sql`) y su traza está en la evidencia como `12-reto-volcado-bloque`. La fila está en el bloque 1158, que ya cae dentro de la extensión de 1 MB (empieza en el 1152), ranura 77.

| | Bloque 783 (fila 101) | Bloque 1158 (fila 19500) |
|---|---|---|
| Bytes de la fila (`tl`) | 78 | 84 |
| Filas en el bloque (`nrow`) | 90 | 85 |
| Cabecera (`hsiz`) | 0xc6 (198) | 0xbc (188) |
| Libre (`avsp`) | 0x361 (865) | 0x33a (826) |
| ITL ranura 1 | `--U-`, `Lck 90` | `--U-`, `Lck 85` |

Las filas del final son más largas porque los ID tienen cinco cifras (`Nombre19500`, `est19500@alu.ucam.edu`) y el estado es `EGRESADO` en vez de `ACTIVO`, así que caben 85 en vez de 90. La cabecera es 10 bytes más pequeña porque el directorio tiene 5 ranuras menos y cada una ocupa 2 bytes. El libre también cuadra: 0x3f6 − 0xbc = 1014 − 188 = 826, y otra fila de 84 + 2 bajaría de los 809 de PCTFREE.

Y sí, también hay limpieza diferida: la ranura 1 tiene el mismo `Xid` (`0x0004.006.000002ae`) y el mismo SCN que el bloque 783, o sea que es la misma transacción de V002, y el `Lck` coincide con el número de filas del bloque (85), porque V002 bloqueó todas las que insertó. El ID también se lee en base 100: `c3 02 60` son tres dígitos, 1 y 95, o sea 1·100² + 95·100 = 19500.

## Parte L — Capacidad y coste: factor de bloqueo, páginas y tiempo

**Predicción frente a realidad en `ACA_ESTUDIANTES` (evidencia 13, capacidad).**

| Cálculo | bfr | Bloques |
|---|---|---|
| Unidad 3 (H = 96, R = 76, PCTFREE 10) | 95 | 211 |
| Versión Oracle (H = 122 con ITL, R + 2 por la ranura) | 93 | 216 |
| Medido (filas por bloque, entre 68 y 95) | 86,6 | 231 con filas |
| Estadísticas (bajo la HWM) | — | 244 |
| Asignado al segmento | — | 256 |

La fórmula acierta el orden de magnitud pero se queda corta: usa la longitud media de la fila y no cuenta que en el bloque cada fila ocupa más (en la Parte K vi que la fila 101 ocupa 78 bytes en el bloque y no 68), que las filas no miden todas lo mismo, que hay 13 bloques casi vacíos al final (244 − 231) y que el espacio se asigna por extensiones enteras (256).

**El coste de una lectura en mi contenedor.**

| Lectura | Medida |
|---|---|
| Lógica (bloque en la buffer cache) | 1,35 µs, 4 por búsqueda (raíz, rama, hoja y tabla) |
| Física aleatoria (1 bloque) | 7,7 µs |
| Secuencial (por bloque) | 18 ms / 4595 bloques ≈ 3,9 µs, unos 87 bloques por petición, ≈ 2 GB/s |

Con esto el umbral sale en el 0,59 % de las filas: si una consulta devuelve más, leer la tabla entera es más barato que ir por el índice.

Estas lecturas "físicas" son demasiado rápidas para ser de disco. El `FLUSH BUFFER_CACHE` vacía la caché de Oracle pero no la de Linux, así que casi todas se sirvieron desde la RAM del sistema. Lo comprobé con la sección 6: la media de toda la instancia desde el arranque es de 464 µs por `db file sequential read`, unas 60 veces más que mis 7,7 µs, porque ahí sí entran las lecturas en frío del arranque, que fueron al disco virtual de WSL. Esos 464 µs se parecen mucho más a un SSD de verdad. En un servidor real se mediría igual y saldría entre 0,1 ms (SSD) y 5-10 ms (HDD), y con un HDD el umbral bajaría a una centésima de punto porcentual.

**Calcular antes de ejecutar.** Con `LECTURAS` (400000 filas, 4676 bloques, unos 86 por bloque), una consulta que devuelve el 2 % (8000 filas) con un índice desordenado tendría que leer 8000 bloques de uno en uno: en el contenedor 8000 × 7,7 µs ≈ 62 ms, con SSD 0,8 s y con HDD 40 s. El recorrido completo son 18 ms en el contenedor y unos 0,25 s en HDD. Gana el recorrido completo en todos los casos, porque el 2 % está muy por encima del umbral.

**P20:** B. bfr = floor((8192 − 96) × 0,9 / 180) = floor(40,48) = 40 filas por bloque, y b = ceil(2000000 / 40) = 50000 bloques.

**P21:** B. `db file scattered read` son lecturas multibloque que van a la buffer cache, lo normal en un recorrido completo. Las de un bloque son `db file sequential read` y las que se saltan la caché, `direct path read`.

## Parte L — Reto: dimensionar ACA_MATRICULAS

Guardé el cálculo en `scripts/lab4/13-reto-matriculas.sql`. Con r = 60000 y R = 30:

| | bfr | Bloques |
|---|---|---|
| Predicción Unidad 3 | 242 | 248 |
| Predicción Oracle | 226 | 266 |
| Medido | 199,3 | 301 con filas |
| Real bajo la HWM | — | 370 |
| Asignado | — | 384 |

Aquí la fórmula falla mucho más que con estudiantes: un 49 % por debajo (248 frente a 370), cuando con estudiantes era un 16 %. Creo que es porque las filas de matrículas son muy cortas (30 bytes) y cada fila paga en el bloque unos bytes fijos: la cabecera, un byte de longitud por columna y los 2 de la ranura. Con lo medido sale 8088 × 0,9 / 199,3 ≈ 36,5 bytes por fila en el bloque, o sea unos 6,5 bytes de sobrecoste para una fila de 30, más del 20 %. En una fila de 76 eso apenas se nota. Además hay 69 bloques bajo la HWM que no tienen filas (370 − 301), porque ASSM formatea bloques por adelantado y no todos se llegan a usar. Conclusión: la fórmula sirve para tener el orden de magnitud, pero para filas cortas hay que medir.

Un recorrido completo en un HDD a 150 MB/s tardaría 370 × 8 KB / 150 MB/s ≈ 19 ms.

## Parte M — Filas migradas y encadenadas

Usé el banco de pruebas de la Parte L (`LAB4_PRUEBAS` en `TBS_LAB4`) y al final se borró entero; comprobé también desde Linux que el archivo `lab4_pruebas01.dbf` ya no está en el volumen (evidencia 14).

**Provocarla.** Creé `MIGRA` con `PCTFREE 0` y 5000 filas de 1 byte: 13 bloques y `CHAIN_CNT 0`. Después agrandé una de cada cinco filas a 300 bytes y, como no había hueco en sus bloques, migraron: la tabla pasó a 58 bloques y `CHAIN_CNT` a 1000, el 20 %, que son justo las filas con id múltiplo de 5. `CHAIN_CNT` solo lo rellena `ANALYZE`, `DBMS_STATS` no lo calcula, y además no distingue migradas de encadenadas, eso hay que razonarlo.

**Detectarla.** Con `ANALYZE ... LIST CHAINED ROWS` salen las 1000 una a una. La primera es el id 735, que tiene la cabeza en el bloque 5643 del archivo 25, ranura 1.

**Lo que cuesta.** 1000 búsquedas por clave hicieron 3200 lecturas lógicas, 3,2 por búsqueda, y `table fetch continued row` subió 200. Una búsqueda normal son 3 lecturas (dos niveles de índice y el bloque de la tabla) y las 200 migradas cuestan 4, porque hay que ir a la cabeza y luego a donde está la fila de verdad: (800 × 3 + 200 × 4) / 1000 = 3,2. Es un 7 % más de trabajo en cada acceso, y eso no se va solo.

**Verla en el bloque.** En el volcado la fila del bloque original sale con `fb: --H-----`, `cc: 0` y `nrid: 0x00001622.25a`. Solo queda la cabeza (Head), sin First ni Last, o sea que los datos no están ahí, y `nrid` dice dónde viven ahora: como es BIGFILE, lo de antes del punto es directamente el bloque, 0x1622 = 5666, y lo de después la ranura. Una fila normal tiene `fb: --H-FL--`, como la 101 de la Parte K.

**Encadenamiento.** En `ANCHA` metí una fila de unos 12000 bytes, que no cabe en ningún bloque de 8 KB, y salió `CHAIN_CNT 1` (la fila corta no cuenta). Esto no es migración: la fila no cabe en ningún bloque, así que reorganizar no lo arregla. Solo se arregla con un bloque más grande (un tablespace de 16 o 32 KB) o separando las columnas grandes.

**Curarla.** `ALTER TABLE ... MOVE PCTFREE 20` reescribe todas las filas y deja `CHAIN_CNT` a 0, pero cambia los ROWID y el índice `PK_MIGRA` se queda `UNUSABLE`, porque apunta a las direcciones viejas. Después de `ALTER INDEX ... REBUILD` vuelve a estar `VALID`. La tabla queda en 63 bloques, más que los 58 de antes, porque ahora cada bloque deja un 20 % libre para que las filas puedan crecer. En producción usaría `MOVE ONLINE`, que mantiene los índices válidos y no bloquea el DML.

**P22:** A y C. `LIST CHAINED ROWS` dice qué filas son y `MOVE ONLINE` con un `PCTFREE` mayor las reescribe sin bloquear. `DBMS_STATS` no rellena `CHAIN_CNT`, y vaciar la caché o tocar el multibloque no tiene nada que ver.

**P23:** B. Si la fila mide 12000 bytes y el bloque 8 KB, está encadenada, y `MOVE` no lo arregla porque no cabe en ningún bloque, igual que me pasó con `ANCHA`.

## Parte N — Autopsia y verificación final

La autopsia está en `docs/bitacora/lab4-autopsia.md` y la verificación final (`16-verificacion-final.sh`) me dio todo OK en las 35 comprobaciones.

**P24:** B. Para un informe diario lo correcto es un usuario común de solo lectura con `SELECT_CATALOG_ROLE`, `CONTAINER_DATA` y el grant puntual de `V_$DIAG_ALERT_EXT`, que es justo `C##OPS_RO`. Con SYS, DBA o SYSTEM el script podría cambiar cualquier cosa, y con la contraseña en el script o en una variable de entorno cualquiera que lo lea la tiene.

## Preguntas de comprobación

### Respaldo y diagnóstico (A)

**1.** Es consistente porque la hice en frío: `backup-estado.sh` hace `SHUTDOWN IMMEDIATE`, que hace checkpoint y cierra todos los archivos con el mismo SCN, y después para el contenedor antes de copiar el volumen (evidencia 00, paso 4). Si la copiara con la base abierta, cada archivo quedaría copiado en un momento distinto mientras DBWn sigue escribiendo, y al restaurarla Oracle encontraría datafiles con SCN diferentes y no abriría sin una recuperación que con una copia de ficheros no se puede hacer.

**2.** `manifiesto.txt` dice qué es la copia (etiqueta `lab3-final`, fecha, volumen, imagen, commit `6f3c918` y 0 archivos fuera del volumen) y `SHA256SUMS` guarda la huella de cada archivo para comprobar que no se ha estropeado (mis 4 líneas salieron `OK`). `restaurar-estado.sh`, antes de tocar nada, comprueba que Docker responde, verifica la copia con `sha256sum --check` y me pide escribir el nombre del volumen para confirmar; si algo falla se para sin haber borrado nada.

**3.** RPO es cuántos datos puedo perder y RTO cuánto tardo en volver a dar servicio. Con mi copia de la Parte A, el RPO es todo lo que pasó desde el 2026-11-13 a las 18:42 UTC hasta el fallo, porque es una copia en frío puntual. El RTO no lo he medido porque no hice un simulacro de restauración; la copia tardó unos 2 min y la base arrancó en unos 5 s en la Parte E, así que calculo unos 3-5 min, pero eso habría que comprobarlo restaurando de verdad.

### Correcciones del Lab 3 (C, D)

**4.** En `$ORACLE_HOME/dbs` (evidencia 01, file# 16 a 20), porque en V000 puse rutas relativas (`'academia01.dbf'`) y `db_create_file_dest` estaba vacío. Lo habría evitado `db_create_file_dest`, que es justo lo que activé en el reto de la Parte C.

**5.** Porque `RENAME DATAFILE` solo cambia la ruta que tiene guardada el control file, no mueve el archivo. Primero hay que copiarlo con el sistema operativo con el tablespace OFFLINE y después hacer el `RENAME` y ponerlo ONLINE.

**6.** V000 ya está aplicada en la base y en el historial de Git; si la edito, el repositorio deja de describir lo que de verdad se ejecutó y otra base creada desde cero quedaría distinta. Lo correcto es una migración nueva, V003. Y borrar la contraseña del archivo no sirve porque sigue en el historial de Git y sigue funcionando en la base: invalidarla hace que deje de servir. Lo demostré en la evidencia 04: antes de V003 entraba como `ADMIN_ACADEMIA` y después daba `ORA-01017`.

**7.** Que todo el estado de la base vive en el volumen y el contenedor se puede tirar y crear otra vez: antes y después salen los mismos tablespaces y las mismas tablas (evidencia 03, 15 s en total). Se hace después de reubicar porque si algún datafile hubiera estado fuera del volumen el `docker rm` se lo habría llevado.

### Instancia, arranque y parámetros (E, F)

**8.** De la instancia: `HOST_NAME = 459c04bb7fae`, `ARRANCADA = 2026-11-14 17:13:41` y los 56-60 procesos `db_*_FREE`. De la base: `DBID = 1509902213`, `CREADA = 2026-07-05` y los 16 datafiles (evidencia 05).

**9.** En NOMOUNT lee el SPFILE y crea la SGA y los procesos, por eso `v$parameter` responde pero `v$database` da `ORA-01507`, porque todavía no ha leído el control file. En MOUNT abre los control files y ya conoce la estructura (`v$database`, 16 datafiles), pero `dba_tables` da `ORA-01219` porque el diccionario está en SYSTEM, que sigue cerrado. En OPEN abre los datafiles y el redo (evidencia 06).

**10.** `v$parameter` es lo que la instancia usa en memoria y `v$spparameter` lo que está escrito en el SPFILE. Con `db_files` se ve: en memoria da `ORA-02095`, y con `SCOPE = SPFILE` salía 200 en memoria y 300 en el SPFILE, pendiente del siguiente arranque; con `RESET` la línea desapareció (evidencia 07, cambios).

**11.** Porque la tabla de procesos se dimensiona en la SGA al arrancar y no se puede ampliar en caliente, aunque la vista lo marque `IMMEDIATE`. Me dio `ORA-02097` + `ORA-02095`, así que solo se cambia con `SCOPE = SPFILE` y reinicio.

### Memoria y procesos (G, H)

**12.** ASMM: `memory_target = 0`, `sga_target = 1536M` y `pga_aggregate_target = 512M` (evidencia 08, memoria). La SGA se reparte sola y la PGA va aparte.

**13.** Con la caché vacía la ronda 1 hizo 357 lecturas lógicas y 262 físicas (26,6 % de acierto), y la ronda 2 247 lógicas y 0 físicas (100 %). Las lógicas no bajan porque toda lectura física termina en una lógica; lo que se ahorra es ir a disco (evidencia 08, caché).

**14.** Con literales: 1008 análisis duros, 530 ms de CPU solo analizando, 570 ms en total, 854 cursores y 31791 KB en la shared pool. Con `:id`: 1 análisis, 10 ms, 1 cursor y 39 KB. Un minuto después ya solo quedaban 740 cursores de los literales, la shared pool había echado 114 (evidencias 08 parse y reto).

**15.** LGWR tiene el SPID 2318 en `v$process` y en `/proc` del contenedor el 2318 es `db_lgwr_FREE`. `docker top` lo enseña como 12762 porque muestra el PID del anfitrión y el contenedor tiene su propio espacio de nombres de PID (evidencia 09).

### Contenedores (I)

**16 a 20** están respondidas en la Parte I, arriba.

### Archivos (J)

**21.** Son la base: los 16 datafiles, los 3 tempfiles, los 2 control files y los 3 grupos de redo online. Relacionados: los 6-7 redo archivados, el SPFILE, el password file y el ADR (evidencia 11). El password file es relacionado porque no guarda datos, solo quién puede entrar como SYSDBA por red; si se pierde, la base sigue y se recrea con `orapwd`.

**22.** 104865792 = 100 × 1048576 + 8192: los 100 MB que dice `v$datafile` más un bloque de 8 KB, el bloque 0, que es la cabecera del archivo y Oracle no lo cuenta como espacio útil.

**23.** Los 2 control files están en la misma carpeta (`FREE/`) y cada grupo de redo tiene un solo miembro. Si se pierde ese disco o se corrompe un redo, no hay copia.

**24.** Porque al recrear el contenedor se pierde la historia del alert log, que es lo primero que se mira en un incidente. A mí me pasó: el alert log saltó del 5 de julio al 14 de noviembre y desapareció todo lo del Lab 3 (Parte J).

### Bloque y fila (K)

**25.** `AAAR2lAAAAAAAMPAAF` = objeto `AAAR2l` (73125) + archivo `AAA` (0, en BIGFILE son bits del bloque) + bloque `AAAAMP` (783) + fila `AAF` (5). Coincide con `ROWID_OBJECT`, con `ROWID_BLOCK_NUMBER(..., 'BIGFILE')` y con `ROWID_ROW_NUMBER` (evidencia 12, tabla completa en la Parte K).

**26.** `nrow` es cuántas filas tiene el bloque (90), `fsbo` dónde empieza el espacio libre (0xc6), `fseo` dónde acaba (0x427) y `avsp` cuánto hay libre. 0x427 − 0xc6 = 0x361, en decimal 1063 − 198 = 865 bytes.

**27.** La ranura 1 de la ITL es la transacción de V002 que insertó las 90 filas: `--U-` quiere decir que está confirmada y `Lck 90` que las 90 filas aún tienen su marca de bloqueo apuntando a ella. La limpieza diferida es que Oracle no limpia esas marcas al hacer `COMMIT` (sería tocar miles de bloques), sino la próxima vez que alguien modifica el bloque y comprueba que la transacción ya terminó. En el bloque 1158 sale lo mismo con `Lck 85` y el mismo `Xid`.

**28.** 78 = 68 bytes de datos (la suma de `VSIZE`) + 7 bytes de longitud, uno por columna (`cc: 7`) + 3 de cabecera de la fila (flag, lock y número de columnas).

### Capacidad y coste (L)

**29.** bfr = floor((8192 − 96) × 0,9 / 76) = 95 y b = ceil(20000 / 95) = 211 bloques. La tabla tiene 244 porque cada fila ocupa más que `AVG_ROW_LEN` en el bloque (78 bytes la 101), las filas no son todas iguales (68 a 95 por bloque, 231 bloques con filas) y hay 13 casi vacíos al final del segmento (evidencia 13).

**30.** Lectura lógica 1,35 µs, física aleatoria 7,7 µs y secuencial 18 ms / 4595 bloques ≈ 3,9 µs por bloque (evidencia 13, 5a-5c).

**31.** Con HDD: c_sec = 8192 / 150 MB/s ≈ 52 µs por bloque y c_aleat = 5 ms, el cociente es 0,0104 y el umbral (1/86) × 0,0104 ≈ 0,012 % de las filas. Con un disco lento casi cualquier consulta que devuelva algo más de un puñado de filas va mejor con un recorrido completo.

**32.** Porque el `FLUSH BUFFER_CACHE` vacía la caché de Oracle pero no la de Linux, y la mayoría de esas lecturas salen de la RAM del sistema. No invalida el método, solo los números: la media de la instancia desde el arranque fue de 464 µs por `db file sequential read`, mucho más parecido a un disco de verdad.

### Filas migradas y encadenadas (M)

**33.** Migración: un `UPDATE` agranda una fila que ya no cabe en su bloque, se va a otro y deja la cabeza con su dirección (`nrid`); se cura con `MOVE` y un `PCTFREE` adecuado. Encadenamiento: la fila no cabe en ningún bloque y se parte en piezas; no se cura reorganizando, solo con un bloque mayor o cambiando el diseño. Las dos se detectan con `ANALYZE` (`CHAIN_CNT`, `LIST CHAINED ROWS`) y con la estadística `table fetch continued row` (evidencia 14).

**34.** Una búsqueda normal son 3 lecturas (dos niveles de índice y la tabla) y las 200 filas migradas cuestan 4, porque hay que ir a la cabeza y después a donde está la fila: (800 × 3 + 200 × 4) / 1000 = 3,2.

**35.** `MOVE` reescribe todas las filas y les cambia el ROWID, y el índice sigue apuntando a los viejos, así que queda `UNUSABLE`. En producción usaría `ALTER TABLE ... MOVE ONLINE`, que mantiene los índices válidos y no bloquea el DML, y después recogería estadísticas.

### Autopsia y trabajo profesional (N, O)

**36.** De `lab4-autopsia.md`: (1) ARCHIVELOG sin FRA, 7 archivados y 1053 MB en `dbs` → pueden llenar el disco → FRA con tamaño máximo (Lab 5) → alta. (2) Control files en la misma carpeta y un miembro por grupo de redo → punto único de fallo → multiplexar (Lab 5) → alta. (3) ADR fuera del volumen → se pierde la historia del alert log al recrear el contenedor → `diagnostic_dest` persistente o logs centralizados → media.

**37.** Porque para observar solo hace falta mirar: SYSTEM puede crear, borrar y cambiar casi todo, y si su contraseña se filtra desde una herramienta de monitorización el daño puede ser enorme. `C##OPS_RO` no puede escribir nada (en la Parte B me dio `ORA-01031` al hacer `CREATE TABLE`), no tiene ningún privilegio `ANY` (lo comprueba la verificación final) y no puede leer los datos de negocio.

**38.** (1) La contraseña de SYS en la línea de comandos: el 08 del Lab 3 montaba `sys/$ORACLE_PWD@...` y se veía con `ps`; el 08 v2 usa `/ as sysdba`. Además el 05 v2 ya no pasa `ORACLE_PWD` al contenedor y no queda en `docker inspect`. (2) Las contraseñas de los `admin_*` escritas en V000 y en el historial de Git, que V003 deja sin valor con `NO AUTHENTICATION`.
