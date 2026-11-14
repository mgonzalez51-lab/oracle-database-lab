-- scripts/lab4/03-omf.sql — reto de la Parte C: activar OMF para que un CREATE TABLESPACE
-- sin ruta no vuelva a dejar el datafile en $ORACLE_HOME/dbs. Se ejecuta como SYSDBA en CDB$ROOT.
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET LINESIZE 200 PAGESIZE 50 FEEDBACK ON
COLUMN name FORMAT A22
COLUMN value FORMAT A30
COLUMN tablespace_name FORMAT A10
COLUMN file_name FORMAT A90
PROMPT == 1. Antes ==
SELECT name, NVL(value, '(vacio: sin OMF)') AS value, ispdb_modifiable FROM v$parameter
 WHERE name = 'db_create_file_dest';
PROMPT == 2. Activar OMF en la raiz (SCOPE=BOTH: en memoria y en el SPFILE) ==
ALTER SYSTEM SET db_create_file_dest = '/opt/oracle/oradata' SCOPE = BOTH;
SELECT 'memoria' AS donde, value FROM v$parameter WHERE name = 'db_create_file_dest'
UNION ALL
SELECT 'spfile', value FROM v$spparameter WHERE name = 'db_create_file_dest';
PROMPT == 3. Prueba en FREEPDB1: CREATE TABLESPACE sin clausula DATAFILE ==
ALTER SESSION SET CONTAINER = FREEPDB1;
DROP TABLESPACE IF EXISTS tbs_x INCLUDING CONTENTS AND DATAFILES;
CREATE TABLESPACE tbs_x;
SELECT tablespace_name, file_name, ROUND(bytes / 1048576) AS mb, autoextensible,
       ROUND(maxbytes / 1048576) AS max_mb
  FROM dba_data_files WHERE tablespace_name = 'TBS_X';
PROMPT == 4. Limpieza: el tablespace de prueba se borra con su datafile ==
DROP TABLESPACE tbs_x INCLUDING CONTENTS AND DATAFILES;
SELECT COUNT(*) AS tbs_x_restantes FROM dba_tablespaces WHERE tablespace_name = 'TBS_X';
EXIT
