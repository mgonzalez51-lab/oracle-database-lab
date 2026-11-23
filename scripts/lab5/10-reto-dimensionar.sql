-- scripts/lab5/10-reto-dimensionar.sql — reto K: cuánto redo genera TiendaSur por hora y qué tamaño de grupo daría <= 4 cambios/hora
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 150 PAGESIZE 50 FEEDBACK OFF
COLUMN hora FORMAT A16
PROMPT ===== 1. Cambios de log y MB de redo archivado por hora (hoy, en UTC) =====
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') || 'h' AS hora, COUNT(*) AS cambios_de_log,
       ROUND(SUM(blocks * block_size) / 1048576) AS mb_redo
  FROM v$archived_log WHERE first_time >= TRUNC(SYSDATE) AND dest_id = 1
 GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24') ORDER BY 1;
PROMPT ===== 2. Propuesta: tamaño de grupo para que la hora de más redo produzca como mucho 4 cambios =====
SELECT ROUND(MAX(mb)) AS mb_hora_pico, CEIL(MAX(mb) / 4) AS mb_minimo_por_grupo,
       CEIL(MAX(mb) / 4 / 256) * 256 AS propuesta_mb_redondeada
  FROM (SELECT SUM(blocks * block_size) / 1048576 AS mb FROM v$archived_log
         WHERE first_time >= TRUNC(SYSDATE) AND dest_id = 1 GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24'));
EXIT
