-- scripts/lab5/02-reto-altura-email.sql — reto C: altura de UX_CLI_EMAIL calculada a mano frente a la medida
-- Cálculo previo (30 bytes por entrada, fo 543): 7996/30 = 266 por hoja, al 90 % unas 240 -> 417 hojas -> altura 1 + ceil(log_543(417)) = 2
-- Sin tablas auxiliares: LAB_TOOLS no tiene cuota (ORA-01950) y no debe tenerla; INDEX_STATS solo guarda el último ANALYZE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 50 FEEDBACK OFF
-- SERVEROUTPUT va después del cambio de contenedor: al cambiar de contenedor se pierde
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON FORMAT WRAPPED
PROMPT ===== Reto C: UX_CLI_EMAIL frente a PK_CLIENTE (mismas 100 000 entradas) =====
DECLARE
  s index_stats%ROWTYPE; fo NUMBER;
BEGIN
  FOR i IN (SELECT 'UX_CLI_EMAIL' AS n FROM dual UNION ALL SELECT 'PK_CLIENTE' FROM dual) LOOP
    EXECUTE IMMEDIATE 'ANALYZE INDEX tiendasur.' || i.n || ' VALIDATE STRUCTURE';
    SELECT * INTO s FROM index_stats;
    fo := FLOOR(s.br_blk_len / (s.br_rows_len / s.br_rows));
    DBMS_OUTPUT.PUT_LINE(RPAD(s.name, 13) || ' altura=' || s.height || '  hojas=' || s.lf_blks || '  ramas=' || s.br_blks
      || '  bytes/entrada hoja=' || ROUND(s.lf_rows_len / s.lf_rows, 1) || '  bytes/entrada rama=' || ROUND(s.br_rows_len / s.br_rows, 1)
      || '  fo_max=' || fo || '  pct_used=' || s.pct_used);
    DBMS_OUTPUT.PUT_LINE(RPAD(' ', 13) || ' altura = 1 + ceil(log_' || fo || '(' || s.lf_blks || ')) = '
      || (1 + CEIL(LN(s.lf_blks) / LN(fo))) || '   (INDEX_STATS dice ' || s.height || ')');
  END LOOP;
END;
/
EXIT
