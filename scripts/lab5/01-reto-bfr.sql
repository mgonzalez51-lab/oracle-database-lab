-- scripts/lab5/01-reto-bfr.sql — reto B: filas por bloque de PEDIDO (mínimo, media y máximo) frente a NUM_ROWS / BLOCKS
-- tbs_tiendasur es BIGFILE: ROWID_BLOCK_NUMBER necesita 'BIGFILE' o devuelve un número de bloque equivocado (Lab 4, Parte K)
SET LINESIZE 150 PAGESIZE 50 FEEDBACK OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
PROMPT ===== 1. Filas por bloque, contadas con el ROWID =====
SELECT COUNT(*) AS bloques_con_filas, MIN(n) AS min_filas, ROUND(AVG(n), 1) AS media, MAX(n) AS max_filas
  FROM (SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE') AS blk, COUNT(*) AS n
          FROM tiendasur.pedido GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE'));
PROMPT ===== 2. Lo que dicen las estadísticas =====
SELECT num_rows, blocks, ROUND(num_rows / blocks, 1) AS bfr_estadisticas FROM dba_tables WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO';
PROMPT ===== 3. Cuántos bloques hay con cada número de filas =====
SELECT n AS filas_en_bloque, COUNT(*) AS bloques
  FROM (SELECT COUNT(*) AS n FROM tiendasur.pedido GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE'))
 GROUP BY n ORDER BY n;
EXIT
