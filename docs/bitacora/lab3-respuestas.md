# Lab 3 — Respuestas de comprobación

## Docker

**1. ¿Qué diferencia hay entre una imagen y un contenedor?**
La imagen es como la receta y el contenedor es el plato que cocinas con ella. Lo vi claro en G2: lancé `docker run hello-world`, Docker me creó un contenedor con el nombre aleatorio `heuristic_ishizaka`, que terminó enseguida, pero la imagen siguió ahí en `docker images`. En G4 pasó lo mismo: creé `prueba` a partir de `alpine:3.20`, lo borré y luego pude crear `prueba2` desde la misma imagen sin volver a descargar nada.

**2. En G5 `nota.txt` desapareció y en G6 no. ¿Por qué?**
En G5 guardé el archivo en `/tmp`, que está dentro del propio contenedor. Cuando hice `docker rm prueba` se fue con él, y al abrir `prueba2` me salió `No such file or directory`. En G6 lo guardé en `/datos`, que era el volumen `datos-prueba` montado desde fuera. Por eso, aunque el contenedor se borró solo (`--rm`), el siguiente contenedor encontró "dato importante" sin problema.

**3. ¿Diferencia entre `docker ps` y `docker ps -a`? ¿Qué significa `Exited (0)`?**
`docker ps` solo enseña los contenedores que están corriendo y `docker ps -a` enseña todos, también los parados. Me pasó en G2: `docker ps` salió vacío y con `-a` sí apareció el hello-world. `Exited (0)` quiere decir que el contenedor terminó y lo hizo bien. Si el número es otro, es que algo falló; de hecho, en mi equipo había contenedores de otra asignatura con `Exited (127)`.

**4. En `-p 8181:8181`, ¿qué número es mi equipo y cuál el contenedor? ¿Y si pongo `-p 80:8080` en nginx?**
El primero es mi equipo y el segundo el contenedor (`anfitrión:contenedor`). Si hubiera puesto `-p 80:8080`, mi puerto 80 mandaría el tráfico al 8080 del contenedor, pero nginx escucha en el 80, así que la página no habría cargado. Yo usé `-p 8080:80`, entré en `localhost:8080` desde Chrome y me salió "Welcome to nginx!". En los logs incluso se veía mi visita.

**5. ¿Por qué Oracle se queda encendido y hello-world termina solo?**
Porque un contenedor dura lo mismo que su proceso principal. hello-world imprime su mensaje y se acaba; el `sh` de Alpine duró hasta que escribí `exit`. En Oracle, el proceso principal es el motor de la base de datos, que no termina nunca, por eso `oralab-26ai` sigue `Up ... (healthy)`.

**6. ¿Qué es el digest y por qué lo guardamos si ya usamos `:latest`?**
El digest es como la huella dactilar de la imagen: un hash SHA-256 que identifica exactamente esa versión. `:latest` es solo una etiqueta y puede apuntar a otra versión dentro de un mes, pero el digest no cambia. En mi evidencia 04 quedó registrado `sha256:f988b0c04c4c...`, así que se sabe exactamente qué Oracle instalé.

**7. ¿Qué comando borraría de verdad los datos de Oracle? ¿Por qué `docker rm oralab-26ai` no lo hace?**
`docker volume rm oralab-26ai-data`, o un `docker system prune -a --volumes` lanzado sin pensar. `docker rm` solo borra el contenedor, pero los datos están en el volumen montado en `/opt/oracle/oradata`, que sobrevive (es lo que comprobé en G6). En mi Docker hay volúmenes de otra práctica, así que tengo claro que nunca voy a hacer un prune masivo sin mirar antes `docker volume ls`.

## Git, organización y evidencia

**8. ¿Por qué hacer el lab dentro del repo, con Issue, branch y PR?**
Porque montar un entorno es un cambio más y tiene que poder revisarse y repetirse. Si mañana se me rompe el portátil, con los scripts del repo vuelvo a tenerlo todo igual. Mi reviewer no tiene que creerme: ve los scripts y lo que salió de verdad. Y queda todo enlazado: Issue #5, branch `chore/5-install-oracle-environment`, un commit por parte y el PR. Si lo hubiera hecho en una carpeta suelta, solo yo sabría cómo lo monté.

**9. ¿Diferencia entre `source 00-config.sh` y `bash 00-config.sh`?**
Con `bash` el script se ejecuta en una terminal aparte que se cierra al acabar, y las variables se pierden. Con `source` se ejecuta en mi propia terminal, así que `CONT_NAME`, `EVID` o la función `ts` siguen disponibles después. Por eso cada vez que abría una terminal nueva lo primero era hacer el `source`.

**10. Explica cada parte de `20261023T184055Z_02-docker.script.log`.**
`20261023T184055Z` es la fecha y hora en UTC: 23/10/2026 a las 18:40:55. La `Z` indica que es UTC, para que no dependa de la zona horaria de quien lo lea, y así los archivos se ordenan solos por fecha. `_02` es el número del paso, `docker` es la descripción en kebab-case y `.script.log` dice que es salida de terminal (los de SQL acaban en `.spool.log` y las capturas en `.png`).

**11. ¿Para qué sirve `.gitattributes` y qué error evita?**
Hace que los `.sh`, `.sql` y `.md` se guarden siempre con finales de línea de Linux (LF), aunque alguien los edite en Windows. Sin esto, un script guardado con CRLF falla en Linux con el típico `$'\r': command not found`, y los diffs se llenan de cambios que no se ven.

**12. ¿Por qué merge commit y no squash?**
Porque cada commit es una parte del lab con su evidencia: Docker, contenedor, migraciones, ORDS… Si hago squash se convierte todo en un único commit y se pierde cómo y cuándo se verificó cada cosa. Aquí el historial paso a paso tiene valor por sí mismo.

## Seguridad

**13. Las cuatro capas de la Parte D. ¿Qué pasa si te saltas la primera?**
Primero meter `config/.env` en el `.gitignore` antes de crear el archivo. Segundo, una plantilla `config/.env.example` con valores de ejemplo, que sí se sube. Tercero, el `config/.env` real en local, comprobando con `git check-ignore -v` que Git lo ignora. Y cuarto, cargar las contraseñas con `set -a; source config/.env; set +a` y usarlas siempre como `"$ORACLE_PWD"`, sin escribirlas nunca a mano. Si te saltas la primera, un `git add .` te mete la contraseña en el historial. A mí casi me pasa con la plantilla: puse un valor real en `.env.example` y lo hice commit. Lo vi a tiempo y lo arreglé con `--amend` antes de hacer push.

**14. ¿Por qué no poner la contraseña directamente en el `docker run`, aunque el script no se suba?**
Porque todo lo que escribes en la terminal se queda guardado en texto plano en `~/.bash_history`, y además puede acabar en logs, en grabaciones de `script` o en capturas. Usando `"$ORACLE_PWD"` solo queda el nombre de la variable. Lo comprobé con `grep -c -F "$ORACLE_PWD"` en todas mis evidencias y salió 0 siempre.

**15. Si descubro mi contraseña en un commit ya publicado, ¿basta con borrarla en otro commit?**
No, porque sigue en el historial y cualquiera puede verla con `git log -p`. Hay que darla por comprometida y cambiarla (rotarla), recrear el contenedor con la nueva y avisar al profesor para limpiar la branch. Si todavía no has hecho push, mejor ni hacerlo.

## Oracle y herramientas

**16. ¿Por qué no usamos SPOOL ni `@archivo.sql` con el sqlplus del contenedor? ¿Qué hicimos?**
Porque ese sqlplus está dentro del contenedor. Un SPOOL guardaría el archivo ahí dentro, no en mi repo, y `@archivo.sql` buscaría un archivo que dentro no existe (error SP2-0310). Lo que hicimos fue pasarle el `.sql` del repo con `< archivo.sql` a través de `docker exec -i` y guardar la salida con `tee`. El SPOOL sí lo usé luego con SQLcl, que corre en mi Ubuntu (evidencia 10).

**17. ¿Qué hace `WHENEVER SQLERROR EXIT SQL.SQLCODE` y qué pasaría sin ella?**
Si una sentencia falla, para el script en ese punto y devuelve el código de error. Sin esa línea, sqlplus seguiría como si nada, por ejemplo creando tablas en un esquema que no llegó a existir, y te quedaría la base a medias. Además, gracias a ese código, mi script `08-aplicar-migraciones.sh` sabe que algo ha fallado y no lanza V001 si V000 ha ido mal.

**18. ¿Qué es una migración y por qué no se editan V000 y V001 una vez aplicadas?**
Es un script SQL numerado que lleva la base de un estado al siguiente, siempre en el mismo orden. Si modificas una que ya se aplicó, las bases que la ejecutaron antes y las nuevas acaban siendo distintas sin que quede rastro. Si hay que corregir algo, se crea otra migración (V002). Por eso no toqué V000 ni V001, aunque la salida se viera partida por el ancho de línea.

**19. ¿Por qué en SQL Developer usamos el servicio FREEPDB1 y no FREE ni un SID?**
FREE es el contenedor raíz (la CDB) y el SID identifica la instancia, no la base donde trabajamos. Con cualquiera de los dos acabaría en la raíz o con un ORA-12505. FREEPDB1 es la base enchufable donde están los 5 esquemas de negocio. Lo confirmé en la primera conexión: `SHOW CON_NAME` devolvió `FREEPDB1`, y en SQL Developer la consulta devolvió `FREE | OPEN`.

**20. ¿Qué aporta SQLcl frente a SQL*Plus y por qué saber usar las dos?**
SQLcl es mucho más cómodo: formatea solo las tablas (`SET SQLFORMAT ansiconsole`), tiene historial, autocompletado, permite guardar conexiones (yo guardé `oralab26-system`) y trae Liquibase. Además se instala en mi equipo, así que el SPOOL va directo al repo. Pero SQL*Plus está en cualquier servidor Oracle, y si un día solo tienes una terminal en el servidor, es lo único que vas a tener. Por eso hay que manejar las dos.

## Entorno de trabajo

**21. ¿Por qué pasamos de Git Bash a Ubuntu en WSL 2? Dos problemas que desaparecen.**
Porque en el trabajo real todo corre en Linux (servidores, contenedores, pipelines), y así practico con los mismos comandos y rutas. Problemas de Git Bash que desaparecen: transforma rutas como `/opt/...` en rutas de Windows y rompe los argumentos de Docker, `docker run -it` falla con "not a TTY" si no usas `winpty`, y no trae herramientas como `free`, `ss` o `htop`. A mí además me apareció un `credential.helper` que apuntaba al Git de Windows, y lo quité para no mezclar programas de los dos sistemas.

**22. ¿Por qué clonar en `~/oracle-database-lab` y no trabajar en `/mnt/c/...`? ¿Y por qué bash en vez de zsh?**
Trabajar en `/mnt/c` obliga a cruzar entre el disco de Windows y el de Linux en cada operación: todo va más lento y se pierden los permisos. Me pasó algo parecido al copiar las capturas desde `/mnt/c`: llegaron con permisos de ejecución y tuve que hacer `chmod 644`. Sobre bash: es la shell que viene por defecto en casi todos los servidores, así que un script en bash funciona en cualquier sitio. zsh está bien para el día a día, pero tiene diferencias en los scripts que pueden dar problemas.
