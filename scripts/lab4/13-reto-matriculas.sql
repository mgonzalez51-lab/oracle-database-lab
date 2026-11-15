-- scripts/lab4/13-reto-matriculas.sql — reto de la Parte L: dimensionar ACA_MATRICULAS con las formulas de la Unidad 3
-- Prediccion (bfr y bloques) frente a realidad (BLOCKS bajo la HWM y bloques asignados) y tiempo de un recorrido
-- completo en un HDD a 150 MB/s. Se ejecuta como SYSDBA: bash scripts/ops/sysdba.sh <este archivo> <evidencia>
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 100 FEEDBACK OFF VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
EXEC DBMS_STATS.GATHER_TABLE_STATS('ADMIN_ACADEMIA', 'ACA_MATRICULAS')
SET SERVEROUTPUT ON
DECLARE
  r NUMBER; rlen NUMBER; pf NUMBER; b NUMBER; bseg NUMBER; medida NUMBER; con_filas NUMBER;
  bfr_u3 NUMBER; bfr_ora NUMBER;
BEGIN
  SELECT t.num_rows, t.avg_row_len, t.pct_free, t.blocks, s.blocks INTO r, rlen, pf, b, bseg
    FROM dba_tables t JOIN dba_segments s ON s.owner = t.owner AND s.segment_name = t.table_name
   WHERE t.owner = 'ADMIN_ACADEMIA' AND t.table_name = 'ACA_MATRICULAS';
  SELECT COUNT(*), ROUND(AVG(n), 1) INTO con_filas, medida
    FROM (SELECT COUNT(*) AS n FROM admin_academia.aca_matriculas
           GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE'));
  bfr_u3  := FLOOR((8192 - 96) * (1 - pf / 100) / rlen);
  bfr_ora := FLOOR((8192 - 122) * (1 - pf / 100) / (rlen + 2));
  DBMS_OUTPUT.PUT_LINE('r = ' || r || ' filas  ·  R = ' || rlen || ' bytes  ·  PCTFREE = ' || pf || ' %');
  DBMS_OUTPUT.PUT_LINE('Prediccion Unidad 3 : bfr = floor((8192-96)*0,9/' || rlen || ') = ' || bfr_u3 || ' -> b = ' || CEIL(r / bfr_u3) || ' bloques');
  DBMS_OUTPUT.PUT_LINE('Prediccion Oracle   : bfr = floor((8192-122)*0,9/(' || rlen || '+2)) = ' || bfr_ora || ' -> b = ' || CEIL(r / bfr_ora) || ' bloques');
  DBMS_OUTPUT.PUT_LINE('Medido              : ' || medida || ' filas por bloque de media en ' || con_filas || ' bloques con filas');
  DBMS_OUTPUT.PUT_LINE('Real                : ' || b || ' bloques bajo la HWM · ' || bseg || ' bloques asignados al segmento');
  DBMS_OUTPUT.PUT_LINE('Recorrido completo en HDD a 150 MB/s: ' || b || ' x 8 KB / 150 MB/s = '
       || ROUND(b * 8192 / (150 * 1048576) * 1000) || ' ms');
END;
/
EXIT
