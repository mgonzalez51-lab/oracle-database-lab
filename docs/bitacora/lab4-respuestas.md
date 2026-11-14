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
