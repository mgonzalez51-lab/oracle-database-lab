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
