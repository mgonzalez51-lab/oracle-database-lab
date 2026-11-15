-- scripts/lab4/08-reto-literales.sql — reto de la Parte G: sentencias que la aplicacion ejecuta con literales
-- Agrupa V$SQL por FORCE_MATCHING_SIGNATURE (misma firma = mismo texto salvo los literales) y muestra
-- las firmas con mas de 50 cursores distintos. Se ejecuta con C##OPS_RO desde la raiz: bash scripts/ops/ro.sh <este archivo>
SET SQLFORMAT DEFAULT
SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF
COLUMN firma FORMAT 99999999999999999999
COLUMN ejemplo FORMAT A75
SELECT force_matching_signature AS firma,
       MIN(con_id)               AS con_id,
       COUNT(*)                  AS cursores,
       SUM(executions)           AS ejecuciones,
       ROUND(SUM(sharable_mem) / 1024) AS kb_shared_pool,
       MIN(SUBSTR(sql_text, 1, 75))    AS ejemplo
  FROM v$sql
 WHERE force_matching_signature <> 0
 GROUP BY force_matching_signature
HAVING COUNT(*) > 50
 ORDER BY cursores DESC;
