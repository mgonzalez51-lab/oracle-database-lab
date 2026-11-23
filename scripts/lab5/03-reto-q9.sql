-- scripts/lab5/03-reto-q9.sql — reto D: ¿merece la pena hacer cubriente IX_PED_FECHA para Q9 (los 20 pedidos más recientes, todas las columnas)?
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 50 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
PROMPT ===== 1. Q9 tal cual, con IX_PED_FECHA =====
EXEC lab_tools.medir.consulta('Q9 con ix_ped_fecha', 'SELECT * FROM tiendasur.pedido ORDER BY fecha_pedido DESC FETCH FIRST 20 ROWS ONLY')
PROMPT ===== 2. Lo que costaría el cubriente: tamaño de la tabla frente al de IX_PED_FECHA =====
SELECT segment_name, ROUND(bytes / 1048576, 1) AS mb FROM dba_segments
 WHERE owner = 'TIENDASUR' AND segment_name IN ('PEDIDO', 'IX_PED_FECHA') ORDER BY segment_name;
PROMPT ===== 3. En cuántos bloques de la tabla están esas 20 filas =====
SELECT COUNT(DISTINCT DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE')) AS bloques_de_tabla
  FROM (SELECT ROWID FROM tiendasur.pedido ORDER BY fecha_pedido DESC FETCH FIRST 20 ROWS ONLY);
EXIT
