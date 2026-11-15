-- scripts/lab4/09-reto-sesion.sql — reto de la Parte H: la sesion de usuario activa que mas consume
-- SID (Oracle), SPID (proceso Linux) y PGA de cada sesion activa, de mayor a menor PGA.
-- Se ejecuta con C##OPS_RO desde la raiz mientras otra sesion trabaja: bash scripts/ops/ro.sh <este archivo>
SET SQLFORMAT DEFAULT
SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF
COLUMN username FORMAT A10
COLUMN spid FORMAT A8
COLUMN program FORMAT A30
COLUMN sentencia FORMAT A60
SELECT s.sid, s.serial#, s.username, p.spid, s.program,
       ROUND(p.pga_used_mem  / 1048576, 1) AS pga_usada_mb,
       ROUND(p.pga_alloc_mem / 1048576, 1) AS pga_asignada_mb,
       SUBSTR(q.sql_text, 1, 60) AS sentencia
  FROM v$session s
  JOIN v$process p ON p.addr = s.paddr
  LEFT JOIN v$sql q ON q.sql_id = s.sql_id AND q.child_number = s.sql_child_number
 WHERE s.type = 'USER' AND s.status = 'ACTIVE'
   AND s.sid <> SYS_CONTEXT('USERENV', 'SID')
 ORDER BY p.pga_alloc_mem DESC;
