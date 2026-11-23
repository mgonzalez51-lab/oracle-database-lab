-- scripts/lab5/12-reto-fra.sql — reto M: cuánto crece la FRA al repetir 12-undo-y-redo (suma del redo medido ≈ 18 MB)
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 150 PAGESIZE 50 FEEDBACK OFF
COLUMN momento FORMAT A22
ALTER SYSTEM ARCHIVE LOG CURRENT;
SELECT 'antes' AS momento, ROUND(space_used / 1048576, 1) AS fra_usada_mb, (SELECT MAX(sequence#) FROM v$archived_log) AS ultima_secuencia FROM v$recovery_file_dest;
@/tmp/12-undo-y-redo.sql
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM ARCHIVE LOG CURRENT;
SELECT 'después' AS momento, ROUND(space_used / 1048576, 1) AS fra_usada_mb, (SELECT MAX(sequence#) FROM v$archived_log) AS ultima_secuencia FROM v$recovery_file_dest;
SELECT sequence#, ROUND(blocks * block_size / 1048576, 1) AS mb FROM v$archived_log WHERE dest_id = 1 ORDER BY sequence# DESC FETCH FIRST 2 ROWS ONLY;
EXIT
