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
