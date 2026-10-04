Lab 1 — Respuestas a las preguntas de comprobación

1\. Working Directory, Staging Area y Local Repository



El Working Directory es la carpeta tal cual la veo y la edito en el disco. La Staging Area es una zona intermedia donde preparo lo que va a entrar en el próximo commit. El Local Repository es el historial de commits guardado dentro de .git.



Ejemplo de la práctica: creé docs/customer-schema.md con Set-Content (estaba solo en el Working Directory, salía como untracked), luego hice git add docs/customer-schema.md (pasó a la Staging Area, en verde en git status) y después git commit (quedó guardado en el repositorio local con su hash).



2\. Si modifico un archivo y no hago git add, ¿entra en el commit?



No. git commit solo guarda lo que está en la Staging Area. Lo vi en el Ejercicio 1 de la Parte E: creé el archivo, hice el commit directamente y Git me respondió "nothing added to commit but untracked files present". El commit no se hizo hasta que añadí el archivo con git add.



3\. ¿Por qué no salían las carpetas vacías en git status?



Porque Git no versiona carpetas, solo archivos. Una carpeta vacía no tiene nada que Git pueda registrar. Después de crear database/schema, scripts, runbooks, etc., en git status solo aparecía README.md. El truco fue meter un archivo .gitkeep dentro de cada carpeta; a partir de ahí sí aparecieron como untracked. .gitkeep es una convención, no algo especial de Git.



4\. ¿Qué es HEAD?



HEAD es un puntero que indica dónde estoy ahora mismo: normalmente apunta a la branch activa, y esa branch apunta a su último commit. En git log --oneline --graph --all lo veo como (HEAD -> main) o (HEAD -> feature/customer-search), según la branch en la que esté. Cuando hago git switch, lo que cambia es a dónde apunta HEAD, y Git actualiza los archivos del disco según ese commit.



5\. Diferencia entre git switch -c y mkdir



mkdir crea una carpeta física en el disco. git switch -c crea una branch, que es solo un puntero dentro de .git a una línea de commits, no una carpeta.



Lo comprobé en la Parte G: después de git switch -c feature/customer-search hice ls -Force y salían exactamente las mismas carpetas que antes, sin ninguna carpeta feature/. Luego hice un commit con docs/customer-search.md en esa branch: al volver a main y hacer ls docs el archivo desaparecía, y al volver a la branch volvía a aparecer. Git cambia el contenido del Working Directory según el commit al que apunta la branch, sin crear carpetas.



6\. ¿Qué había entre los marcadores del conflicto?



Entre <<<<<<< HEAD y ======= estaba la versión de la branch en la que estaba (main), que ya tenía fusionada fix/readme-title: # Oracle Database Lab (Training Edition).



Entre ======= y >>>>>>> fix/readme-subtitle estaba la versión de la branch que estaba fusionando: # Oracle Database Lab — Academic Version.



Lo resolví combinando las dos en # Oracle Database Lab (Training Edition — Academic Version), borré los tres marcadores, comprobé que no quedaba ninguno y cerré el merge con merge: resolve README title conflict (commit a3fb424).



7\. ¿Por qué no hacer --amend sobre un commit ya subido?



Porque --amend no modifica el commit, lo sustituye por otro nuevo con un hash distinto. Si ese commit ya está en GitHub y otra persona lo ha descargado, mi historial y el suyo dejan de coincidir y el siguiente push o pull da problemas. Mientras el commit sea solo local se puede usar sin riesgo; una vez subido, para corregir algo hay que hacer un commit nuevo.



En mi caso, el commit dcos: fxi typo (23a9577) se quedó en el historial y ya lo he subido a GitHub con git push -u origin main, así que no lo voy a reescribir con --amend: ya es público.



8\. ¿Qué se pierde si borro la carpeta .git?



Se pierde todo el historial: los commits, las branches, los merges, la configuración del repositorio y el vínculo con el remoto. Los archivos que están en ese momento en el disco no se pierden, porque están en el Working Directory, pero pasan a ser una carpeta normal sin control de versiones. Lo que solo existía en otras branches (por ejemplo docs/customer-search.md si estoy en main) sí se perdería, a no ser que esté subido a GitHub.



9\. Diferencia entre Git y GitHub



Git es el programa que tengo instalado en mi ordenador y que gestiona el historial: init, add, commit, branch, merge y log funcionan sin conexión. Toda la práctica hasta la Parte H la hice sin GitHub. GitHub es una plataforma web que guarda copias de repositorios Git en sus servidores para poder compartirlos y trabajar en equipo, y añade cosas como Pull Requests, Issues, revisiones de código y protección de branches.



En la Parte I conecté los dos: con git remote add origin https://github.com/mgonzalez51-lab/oracle-database-lab le dije a mi Git local dónde está la copia de GitHub, y con git push -u origin main subí mis commits. Al hacer push de fix/readme-title, GitHub me ofreció crear un Pull Request, que es algo que Git por sí solo no tiene. Git funciona sin GitHub, pero GitHub no funciona sin Git.



10\. ¿Por qué no subir un .env con contraseñas aunque el repo sea privado?



Porque una vez hecho el commit, la contraseña queda en el historial para siempre, aunque después borre el archivo. Un repositorio privado puede pasar a público, otras personas pueden tener acceso o pueden clonarlo, y si alguien entra en la cuenta tiene todas las credenciales. Lo correcto es poner .env en .gitignore desde el primer commit y subir solo un .env.example sin valores reales. Si se sube por error, hay que cambiar la credencial inmediatamente.



11\. GitHub rechaza el push con "non-fast-forward"



Significa que en el remoto hay commits que mi compañero no tiene en local (por ejemplo, porque otra persona subió algo antes o se editó un archivo desde la web), así que Git no puede añadir sus commits encima sin perder los otros. Lo primero sería ejecutar git pull para traer y fusionar esos cambios, resolver el conflicto si aparece, y después volver a hacer git push.



Es lo que simulé en el Paso 4 de la Parte I: edité README.md desde la web de GitHub en la rama fix/readme-subtitle, así que el remoto tenía un commit que yo no tenía en local. Con git pull en esa rama me lo traje. Si en vez de eso hubiera hecho un commit local y un git push, me habría salido justo este rechazo.



12\. Tipos de Conventional Commits

Añadir un índice de rendimiento a una tabla: perf, por ejemplo perf(db): add index on customer email.

Corregir una restricción mal definida: fix, por ejemplo fix(db): correct customer foreign key constraint.

Actualizar el README: docs, por ejemplo docs: update README with project structure.



Incidencias que tuve durante la práctica:

Git no estaba instalado (git no se reconocía); lo instalé y configuré user.name y user.email.

Al abrir PowerShell como administrador estaba en C:\\Windows\\system32 y mkdir daba acceso denegado; me moví a mi carpeta de usuario.

ls -la no existe en PowerShell; usé ls -Force para ver la carpeta oculta .git. Tampoco usé touch ni echo >, sino New-Item, Set-Content y Add-Content.

La rama se creó como master; en la Parte G git switch main falló y la renombré con git branch -m master main.

git show <hash> falló porque en PowerShell < es un operador reservado; hay que escribir el hash sin los símbolos.

En el primer intento de la Parte H no salió el conflicto porque las branches no partían del mismo punto de main. Volví al commit 85109db con git reset --hard, recreé las dos branches desde main y en el segundo intento sí apareció el conflicto.

En la Parte E el --amend no sustituyó el commit dcos: fxi typo (23a9577) porque se hizo un commit nuevo encima (85109db). --amend debería haber reemplazado ese commit en lugar de añadir otro. Como ya está subido a GitHub, lo dejo así y no reescribo el historial.

En la Parte I conecté el repositorio con https://github.com/mgonzalez51-lab/oracle-database-lab. Al hacer el primer push se abrió la autenticación en el navegador y, a partir de ahí, main, fix/readme-title y fix/readme-subtitle quedaron subidas y vinculadas con -u a su rama remota.

En el Paso 4, el primer git pull me dio "Already up to date" porque todavía no había editado nada en la web. Después edité README.md desde GitHub en la rama fix/readme-subtitle, volví a hacer git pull y se descargó el cambio.

En PowerShell, cat README.md muestra â€” en lugar de —. El archivo está bien en UTF-8; es un problema de cómo lo muestra PowerShell 5 (con Get-Content README.md -Encoding UTF8 se ve correcto).

En la rama fix/readme-subtitle la primera línea quedó como # \\# Oracle Database Lab — Academic Version por un \\# que se coló al editar. En main no afecta porque el título final lo puse a mano al resolver el conflicto.

