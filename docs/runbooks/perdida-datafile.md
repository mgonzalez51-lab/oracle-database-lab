# Runbook: pérdida de un datafile de negocio (Oracle 23ai, contenedor `oralab-26ai`)

Probado en el simulacro D del Lab 5 (Issue #9): `academia01.dbf` (n.º 16, TBS_ACADEMIA) recuperado en 8 s con RPO = 0.

## 1. Síntoma

Una consulta sobre una tabla del tablespace falla con estos tres errores:

| Error | Qué dice |
|---|---|
| `ORA-01116: error in opening database file 16` | Oracle no puede abrir el archivo n.º 16 |
| `ORA-01110: data file 16: '/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf'` | **Qué archivo** es |
| `ORA-27041` + `Linux-x86_64 Error: 2: No such file or directory` | **La causa** en el sistema operativo: el archivo no existe |

Desde 21c, al detectar el fallo de medio Oracle puede **cerrar la PDB entera** para protegerla (`ORA-63999` en el alert log). En ese caso, todas las aplicaciones de la PDB se caen, no solo las del tablespace.

## 2. Comprobaciones previas (no tocar nada hasta tenerlas)

```bash
docker exec -i oralab-26ai sqlplus -s / as sysdba <<'EOF'
SELECT log_mode FROM v$database;                              -- tiene que ser ARCHIVELOG
SELECT name, open_mode FROM v$pdbs WHERE name = 'FREEPDB1';   -- READ WRITE o MOUNTED: decide el camino
SELECT file#, name FROM v$datafile WHERE file# = 16;
EXIT
EOF
docker exec -i oralab-26ai rman target / <<'EOF'
LIST BACKUP OF DATAFILE 16;                                   -- tiene que haber al menos una copia
EOF
```

**Si la base está en NOARCHIVELOG o no hay copia, parar y escalar:** RESTORE + RECOVER no puede recuperar sin perder datos.

## 3. Reparación (n = número del archivo, aquí 16)

**Camino A: la PDB sigue en READ WRITE.** Solo el tablespace está caído, el resto de la PDB sigue dando servicio.

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE 16 OFFLINE;
```
```
RMAN> RESTORE DATAFILE 16;
RMAN> RECOVER DATAFILE 16;
```
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE 16 ONLINE;
```

**Camino B: Oracle cerró la PDB (MOUNTED, ORA-63999).** Esperar a que esté completamente MOUNTED (no a medio cerrar), y entonces:

```
RMAN> RESTORE DATAFILE 16;
RMAN> RECOVER DATAFILE 16;
```
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE 16 ONLINE;
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
```

No olvidar el `RECOVER`: el archivo restaurado tiene el SCN de la copia y Oracle no lo deja ponerse ONLINE hasta aplicarle el redo.

## 4. Verificar

```sql
SELECT name, open_mode FROM v$pdbs WHERE name = 'FREEPDB1';             -- READ WRITE
SELECT file#, status FROM v$datafile WHERE file# = 16;                   -- ONLINE
SELECT COUNT(*) FROM admin_academia.aca_estudiantes;                     -- 20000
SELECT estado FROM admin_academia.aca_estudiantes WHERE estudiante_id = 104;  -- el último cambio confirmado tiene que estar
```

En el alert log tiene que aparecer `media recovery complete` sin nuevos ORA-.

## 5. Avisar

- **Durante:** al responsable de la aplicación, con el alcance (solo el tablespace en el camino A; toda FREEPDB1 en el B) y una estimación (en la prueba fueron segundos).
- **Después:** al equipo de sistemas, para que revise el disco o el volumen (el archivo no desaparece solo), y abrir un Issue con la línea de tiempo, el RTO y el RPO medidos.
- **Siguiente paso:** hacer una copia RMAN nueva del tablespace, porque la anterior ya no cubre lo que se haya hecho desde entonces sin el redo archivado.
