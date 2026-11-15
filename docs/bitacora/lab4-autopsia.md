# Lab 4 — Informe de autopsia de la instancia

Miguel Gonzalez Corvillo · mgonzalez51-lab · Issue #7

Base `FREE` (DBID 1509902213), Oracle 23.26.3, contenedor `oralab-26ai`. Saqué los datos con `15-autopsia-instancia.sql` usando `C##OPS_RO` (solo lectura) el 2026-11-15 (evidencia 15), y algunos de partes anteriores, que indico en cada caso.

## Lo que está bien

- Los cinco datafiles de negocio están en `FREE/FREEPDB1` dentro del volumen y con techo de 1 GB (Parte C), y el contenedor se puede recrear sin perder datos (prueba de persistencia, 15 s).
- Ninguna cuenta `ADMIN_*` tiene contraseña (V003) y ninguna cuenta creada por nosotros tiene el rol DBA (sección 7, 0 filas).
- El contenedor ya no publica el 8181 y no lleva ninguna contraseña en `docker inspect`.
- La verificación final (`16-verificacion-final.sh`) da TODO OK.

## Hallazgos

| # | Sección | Evidencia | Riesgo | Acción | Prioridad |
|---|---|---|---|---|---|
| 1 | 1 y 4 | `ARCHIVELOG` pero `db_recovery_file_dest` vacío; 7 archived logs con 1053 MB en `$ORACLE_HOME/dbs` (eran 6 y 856 MB en la Parte J, el día antes) | Los archivados crecen sin límite y sin que nadie los borre hasta llenar el disco, y además tienen extensión `.dbf`, así que se pueden confundir con datafiles | Configurar la FRA con un tamaño máximo y una política de borrado de archivados (Lab 5) | Alta |
| 2 | 4 | 2 control files en la misma carpeta (`FREE/`) y 3 grupos de redo con un solo miembro cada uno | Si se pierde ese disco o se corrompe un redo, no hay copia: punto único de fallo | Multiplexar control files y miembros de redo en sitios distintos (Lab 5) | Alta |
| 3 | Parte J | `/opt/oracle/diag` vive en la capa del contenedor; al recrearlo el alert log volvió al 5 de julio y se perdieron las entradas del Lab 3 y del 13 de noviembre | Al recrear el contenedor no se pierden datos, pero sí la historia del alert log, que es justo lo que hace falta para analizar un incidente | Llevar `diagnostic_dest` a almacenamiento persistente o enviar los logs a una plataforma central | Media |
| 4 | 6 | `ALTURA_MAX` vacía en `ADMIN_CLINICA`, `ADMIN_FINTECH`, `ADMIN_LOGISTICA` y `ADMIN_RETAIL` | Sin estadísticas el optimizador elige los planes a ciegas | `DBMS_STATS.GATHER_SCHEMA_STATS` en esos esquemas y comprobar que el job automático de estadísticas está activo | Media |
| 5 | 5 | `UNDOTBS1` con máximo de 33554432 MB (32 TB) en la raíz y en FREEPDB1, y SYSTEM/SYSAUX con unos 950 GB, o sea el disco entero | Una transacción enorme o un error podría hacer crecer el undo hasta llenar el volumen, como pasa con OMF sin `MAXSIZE` (Parte C) | Poner `MAXSIZE` a los tablespaces de sistema y undo y vigilar su uso | Media |
| 6 | 2 | `maximum PGA allocated` = 657 MB con `pga_aggregate_target` = 512 MB | No es un error (el objetivo no es un límite y `pga_aggregate_limit` es 2 GB), pero si se acercara al límite Oracle empezaría a cortar sesiones | Vigilarlo. Aquí lo provocaron mis pruebas de las Partes G y L | Baja |
| 7 | 6 | 2 índices de `ADMIN_ACADEMIA` con factor de agrupamiento cercano al número de filas | Esos índices salen caros para consultas por rangos | Analizarlos en el Lab 5 | Baja |
| 8 | 7 | 9 cuentas locales "de la casa" en FREEPDB1 | Alguna puede ser de laboratorios anteriores (por ejemplo, la que creó la imagen en el Lab 3 con `APP_USER`) y tener contraseña sin necesitarla | Listarlas con `cdb_users` y bloquear o quitar lo que no se use | Baja |
| 9 | 10 | 7 errores ORA- en 24 h: ORA-00800 (×4), ORA-959 (×2) y ORA-65025 (×1) | Todos son conocidos: ORA-00800 es el contenedor sin permiso para subir la prioridad de VKTM y LGWR; ORA-959 sale de mis `DROP TABLESPACE IF EXISTS` (reto de OMF y `13-capacidad`); ORA-65025 lo provoqué en la Parte I | Documentarlos y excluirlos de las alertas; cualquier otro código se investiga | Baja |
| 10 | 9 | `_instance_recovery_bloom_filter_size` cambiado | Es un parámetro oculto que viene de la imagen y nadie de nosotros lo tocó | Documentarlo; los parámetros ocultos solo se cambian con indicación de Oracle | Baja |

## Resumen para dirección

La base funciona bien, los datos están a salvo dentro del volumen y los fallos de seguridad del Lab 3 están corregidos.
Lo urgente es la protección: no hay copias duplicadas de los archivos críticos y los archivados crecen sin control hasta poder llenar el disco.
Las dos cosas se arreglan en el Lab 5 (multiplexar y configurar la FRA) sin parar el servicio más de unos minutos.
