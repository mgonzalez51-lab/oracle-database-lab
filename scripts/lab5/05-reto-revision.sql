-- scripts/lab5/05-reto-revision.sql — reto F: revisión del PR del compañero (panel de atención al cliente)
-- Consulta propuesta: WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL'
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 50 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
DECLARE PROCEDURE quitar(p VARCHAR2) IS BEGIN EXECUTE IMMEDIATE p; EXCEPTION WHEN OTHERS THEN NULL; END;
BEGIN quitar('DROP INDEX tiendasur.ix_cli_telefono'); quitar('DROP INDEX tiendasur.ix_cli_apellidos'); END;
/
PROMPT ===== 0. Qué devuelve cada condición (para no "optimizar" una consulta que está mal) =====
SELECT SUM(CASE WHEN SUBSTR(telefono, 1, 3) = '600' THEN 1 ELSE 0 END) AS tel_600,
       SUM(CASE WHEN UPPER(apellidos) = 'GIL' THEN 1 ELSE 0 END) AS apellidos_igual_gil,
       SUM(CASE WHEN apellidos LIKE '% Gil' THEN 1 ELSE 0 END) AS segundo_apellido_gil
  FROM tiendasur.cliente;
PROMPT ===== 1. Tal como viene en el PR (sin índices en telefono ni apellidos) =====
EXEC lab_tools.medir.consulta('PR original', q'[SELECT * FROM tiendasur.cliente WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL']')
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono);
CREATE INDEX tiendasur.ix_cli_apellidos ON tiendasur.cliente (apellidos);
PROMPT ===== 2. El PR original CON índices: las funciones los inutilizan =====
EXEC lab_tools.medir.consulta('PR original + índices', q'[SELECT * FROM tiendasur.cliente WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL']')
PROMPT ===== 3. Reescrita: columnas desnudas, prefijo con LIKE y el dato como se guarda =====
EXEC lab_tools.medir.consulta('Reescrita (mismo resultado)', q'[SELECT * FROM tiendasur.cliente WHERE telefono LIKE '600%' OR apellidos = 'Gil']')
EXEC lab_tools.medir.consulta('Reescrita (2.º apellido Gil)', q'[SELECT * FROM tiendasur.cliente WHERE telefono LIKE '600%' OR apellidos LIKE '% Gil']')
PROMPT ===== Limpieza =====
DROP INDEX tiendasur.ix_cli_telefono;
DROP INDEX tiendasur.ix_cli_apellidos;
SELECT COUNT(*) AS indices_tiendasur FROM dba_indexes WHERE owner = 'TIENDASUR';
EXIT
