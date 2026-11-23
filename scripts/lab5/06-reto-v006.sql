-- scripts/lab5/06-reto-v006.sql — reto G: las cinco preguntas aplicadas a un índice propio (CLIENTE.telefono para Q5)
-- Crea el índice, mide y lo BORRA: la decisión se documenta como V006 en una rama aparte, sin aplicarla aquí
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 50 FEEDBACK OFF
COLUMN index_name FORMAT A16
COLUMN columnas FORMAT A30
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
DECLARE PROCEDURE quitar(p VARCHAR2) IS BEGIN EXECUTE IMMEDIATE p; EXCEPTION WHEN OTHERS THEN NULL; END;
BEGIN quitar('DROP INDEX tiendasur.ix_cli_telefono'); END;
/
COLUMN tel NEW_VALUE tel NOPRINT
SELECT telefono AS tel FROM tiendasur.cliente WHERE id_cliente = 4711;
PROMPT ===== 1 · NECESIDAD: Q5 (identificar a quien llama) sin el índice =====
EXEC lab_tools.medir.consulta('Q5 sin ix_cli_telefono', q'[SELECT * FROM tiendasur.cliente WHERE email = '&tel' OR telefono = '&tel']')
PROMPT ===== 3a · ESCRITURA en CLIENTE sin el índice (2000 altas de cliente, deshechas) =====
EXEC lab_tools.medir.dml('CLIENTE INSERT sin', q'[BEGIN FOR i IN 1 .. 2000 LOOP INSERT INTO tiendasur.cliente VALUES (900000 + i, 'Z' || LPAD(i, 8, '0'), 'alta' || i || '@tiendasur.es', 'N', 'A', '6' || LPAD(i, 8, '0'), 'ES', 'Lorca', SYSDATE); END LOOP; END;]', 2000)
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono) ONLINE;
PROMPT ===== 1 · NECESIDAD: Q5 con el índice =====
EXEC lab_tools.medir.consulta('Q5 con ix_cli_telefono', q'[SELECT * FROM tiendasur.cliente WHERE email = '&tel' OR telefono = '&tel']')
PROMPT ===== 2 · VIABILIDAD: selectividad de telefono =====
SELECT index_name, distinct_keys AS claves, num_rows AS entradas, ROUND(100 / distinct_keys, 4) AS pct_por_valor, clustering_factor AS cf
  FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name = 'IX_CLI_TELEFONO';
PROMPT ===== 3b · ESCRITURA en CLIENTE con el índice =====
EXEC lab_tools.medir.dml('CLIENTE INSERT con', q'[BEGIN FOR i IN 1 .. 2000 LOOP INSERT INTO tiendasur.cliente VALUES (900000 + i, 'Z' || LPAD(i, 8, '0'), 'alta' || i || '@tiendasur.es', 'N', 'A', '6' || LPAD(i, 8, '0'), 'ES', 'Lorca', SYSDATE); END LOOP; END;]', 2000)
PROMPT ===== 4 · REDUNDANCIA: ¿algún índice de CLIENTE empieza ya por telefono? =====
SELECT i.index_name, LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_position) AS columnas
  FROM dba_indexes i JOIN dba_ind_columns c ON c.index_owner = i.owner AND c.index_name = i.index_name
 WHERE i.owner = 'TIENDASUR' AND i.table_name = 'CLIENTE' GROUP BY i.index_name ORDER BY 1;
PROMPT ===== Coste en espacio =====
SELECT segment_name AS index_name, ROUND(bytes / 1048576, 1) AS mb FROM dba_segments WHERE owner = 'TIENDASUR' AND segment_name = 'IX_CLI_TELEFONO';
PROMPT ===== Limpieza: la decisión va en V006 (rama aparte), no se aplica aquí =====
DROP INDEX tiendasur.ix_cli_telefono;
SELECT COUNT(*) AS indices_tiendasur FROM dba_indexes WHERE owner = 'TIENDASUR';
EXIT
