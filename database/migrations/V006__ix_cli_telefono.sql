-- database/migrations/V006__ix_cli_telefono.sql
-- Propuesta (Lab 5, reto G): índice en CLIENTE.telefono para Q5 (atención al cliente identifica a quien llama por email o teléfono)
-- Protocolo de cinco preguntas, medido en el banco (evidencia 06-reto-v006):
--   1 Necesidad    Q5 con OR email/telefono: 1486 -> 6 lecturas lógicas (BITMAP OR con ux_cli_email)
--   2 Viabilidad   99 952 valores distintos en 100 000 filas: 0,001 % por valor
--   3 Escritura    INSERT en CLIENTE: 10,2 -> 12,2 bloques por fila y 1392 -> 1627 bytes de redo (+2 bloques, lo esperado)
--   4 Redundancia  ningún índice de CLIENTE empieza por telefono
--   5 Ciclo de vida 3 MB; ONLINE; vigilar DBA_INDEX_USAGE y, si no se usa, INVISIBLE antes de DROP
-- Idempotente: si ix_cli_telefono ya existe, no hace nada.
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
WHENEVER SQLERROR EXIT SUCCESS
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_indexes WHERE owner = 'TIENDASUR' AND index_name = 'IX_CLI_TELEFONO';
  IF n > 0 THEN RAISE_APPLICATION_ERROR(-20006, 'V006 ya aplicada: IX_CLI_TELEFONO existe, no se hace nada'); END IF;
END;
/
WHENEVER SQLERROR EXIT SQL.SQLCODE
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente (telefono) ONLINE;
EXIT
