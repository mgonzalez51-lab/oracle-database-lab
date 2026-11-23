-- scripts/lab5/08-reto-mttr.sql — reto I: cómo crece el MTTR estimado con redo pendiente (UPDATE de 20 000 filas sin checkpoint)
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 160 PAGESIZE 50 FEEDBACK OFF
COLUMN momento FORMAT A30
PROMPT ===== MTTR y redo pendiente: antes, justo después del UPDATE y 30 s más tarde (sin ALTER SYSTEM CHECKPOINT) =====
SELECT '1. antes' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks, recovery_estimated_ios FROM v$instance_recovery;
ALTER SESSION SET CONTAINER = FREEPDB1;
UPDATE admin_academia.aca_estudiantes SET estado = estado;
COMMIT;
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT '2. justo después (20 000 filas)' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks, recovery_estimated_ios FROM v$instance_recovery;
EXEC DBMS_SESSION.SLEEP(30)
SELECT '3. 30 s después' AS momento, estimated_mttr, actual_redo_blks, target_redo_blks, recovery_estimated_ios FROM v$instance_recovery;
EXIT
