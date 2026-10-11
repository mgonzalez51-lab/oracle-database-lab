\# Lab 2 – Respuestas a las preguntas de comprobación



Alumno: Miguel Gonzalez Corvillo

Asignatura: Administración de Bases de Datos

Repositorio: oracle-database-lab



\---



\## 1. ¿Por qué un Issue sin criterios de aceptación es un problema, aunque la descripción parezca clara?



Porque no hay forma de saber cuándo está terminado. Una descripción como "mejorar la documentación" puede parecer clara, pero cada persona la va a entender de una manera distinta. Los criterios de aceptación convierten la idea en una checklist que se puede comprobar. En mi caso, el Issue #1 tenía 4 criterios (que exista CONTRIBUTING.md, que explique las branches, que explique Conventional Commits y que esté enlazado desde el README). Luego el reviewer los usó para revisar el PR. Sin ellos no habría tenido nada objetivo con lo que comparar.



\## 2. Diferencia entre "Refs #N" y "Closes #N"



"Refs #N" solo crea una referencia: el commit o el PR aparece enlazado en el Issue, pero el Issue sigue abierto. "Closes #N" (o "Fixes" / "Resolves") además cierra el Issue automáticamente cuando ese commit o PR llega a main. Yo usé "Refs #1" en los commits porque el trabajo todavía no estaba terminado, y "Closes #1" en la descripción del PR. Así el Issue se cerró justo al hacer el merge y no antes.



\## 3. ¿Qué pasa si haces git push directamente sobre una main protegida? ¿Es un error tuyo o del sistema?



GitHub rechaza el push con el error "GH006: Protected branch update failed" y el mensaje de que los cambios tienen que hacerse a través de un Pull Request. No es un fallo del sistema, es la protección funcionando como debe. En mi caso tuve que activar "Do not allow bypassing the above settings", porque como soy el propietario del repo GitHub me dejaba saltarme la regla. Con esa opción activada el push se rechazó. La solución nunca es forzar el push, sino crear una branch y abrir un PR.



\## 4. "He aprobado el PR sin mirar los archivos, total ya me fío". ¿Qué riesgo tiene?



La aprobación pierde todo su sentido, porque se convierte en un trámite (lo que se llama rubber-stamping). Pueden entrar en main errores, cambios accidentales, contraseñas o datos sensibles, o código que no cumple los criterios del Issue. Además da una falsa sensación de seguridad: parece que alguien lo ha revisado, pero en realidad nadie lo ha hecho. Revisar no es desconfiar del compañero, es comprobar el cambio, que es justo de lo que va el laboratorio.



\## 5. Si el reviewer pide un cambio y ya has hecho push, ¿tienes que abrir un PR nuevo?



No. El PR está vinculado a la branch, no a un commit concreto. Si haces un commit nuevo en la misma branch y haces push, el PR se actualiza solo con ese commit. Es lo que me pasó en la Parte G: el PR #2 pasó de 1 a 2 commits, el reviewer vio el aviso "New changes since you last viewed" y pudo revisar solo lo nuevo. Abrir un PR nuevo rompería el hilo de la conversación y se perdería el historial de la revisión.



\## 6. Diferencia entre Merge commit, Squash and merge y Rebase and merge. ¿Cuál usarías para commits "wip", "fix", "fix2", "ok ya"?



\- \*\*Merge commit:\*\* mete todos los commits de la branch en main tal cual y añade un commit extra de fusión.

\- \*\*Squash and merge:\*\* junta todos los commits de la branch en uno solo antes de meterlo en main.

\- \*\*Rebase and merge:\*\* reaplica los commits uno a uno encima de main, sin commit de fusión, así que el historial queda lineal.



Para una branch con commits tipo "wip", "fix", "fix2" u "ok ya" usaría Squash and merge, porque esos commits no aportan nada por separado y solo ensuciarían el historial de main. Es lo que hicimos en la práctica con el PR #2.



\## 7. ¿Por qué borrar una branch después del merge no elimina el trabajo?



Porque una branch en Git es solo un puntero a un commit, no una carpeta con los archivos. Cuando haces el merge, los cambios ya están en main. Si borras la branch, solo desaparece ese puntero, que ya no hace falta. En mi caso, al usar squash, todo el trabajo quedó en el commit "docs: add contribution guidelines (#2)" dentro de main, y lo comprobé con git log y cat CONTRIBUTING.md después de borrar la branch.



\## 8. ¿Qué información debería contener siempre la descripción de un PR?



Como mínimo tiene que responder a cuatro cosas:

\- \*\*Qué\*\* hace el cambio (Summary).

\- \*\*Por qué\*\* se hace, con el enlace al Issue (Related Issue, por ejemplo Closes #1).

\- \*\*Cómo\*\* se ha probado o cómo probarlo (Testing).

\- \*\*Evidencia visual\*\* cuando aplica, por ejemplo capturas del antes y el después si hay cambios de interfaz.



Yo añadí también una lista de Changes con los archivos modificados, para que el reviewer supiera qué iba a encontrarse antes de abrir el diff.



\## 9. Un reviewer escribe solo "esto está mal". ¿Qué le falta? Reescríbelo.



Le falta todo: qué es lo que está mal, por qué importa, qué propone para arreglarlo y si es bloqueante o no. Así el autor no sabe qué hacer y encima se lo toma como algo personal.



Ejemplo inventado, sobre un script que borra registros de una tabla de pedidos:



> issue (blocking): este DELETE no tiene WHERE, así que borraría todos los registros de la tabla PEDIDOS y no solo los cancelados. Propongo añadir `WHERE estado = 'CANCELADO'` y probarlo antes con un SELECT para ver cuántas filas afecta.



\## 10. ¿Qué diferencia hay entre que main esté protegida y que el equipo "se ponga de acuerdo"?



El acuerdo depende de que todo el mundo se acuerde y lo cumpla siempre, y al final alguien con prisas o por despiste hace push directo. Con main protegida, la regla la aplica GitHub automáticamente y no hay forma de saltársela (sobre todo si activas que tampoco los administradores puedan hacerlo). Lo vi en la Parte H: aunque yo quería hacer el push, GitHub no me dejó. Una cosa es una política "de palabra" y otra una política aplicada técnicamente.



\## 11. Ejemplo de issue (blocking) frente a nitpick (if-minor)



\- \*\*issue (blocking):\*\* "El script de migración crea la tabla CLIENTES pero no tiene su rollback correspondiente. Si falla en producción no hay forma de volver atrás. Hay que añadir el DROP TABLE en el script de rollback antes de aprobar."

\- \*\*nitpick (if-minor):\*\* "En el README pones 'Base de datos' con mayúscula y en CONTRIBUTING 'base de datos' en minúscula. No es importante, pero si lo cambias queda más uniforme."



La diferencia es que el primero impide aprobar el PR hasta que se arregle, porque afecta al funcionamiento. El segundo es un detalle de estilo que el autor puede cambiar o no; no bloquea nada.



\## 12. Si el próximo commit es "feat!: cambia la firma de la función principal de la API", ¿qué versión SemVer se dispara?



Una versión MAJOR, por ejemplo de 2.1.0 a 3.0.0. El símbolo "!" indica que es un breaking change: al cambiar la firma de la función, el código que ya la usaba deja de funcionar. Aunque sea un "feat", que normalmente solo subiría la versión MINOR, el "!" hace que suba la MAJOR para avisar a quien use la API de que tiene que adaptar su código.



\## 13. ¿Por qué abrir un Draft PR desde el primer commit estructural ahorra tiempo al equipo?



Porque permite que los compañeros validen el enfoque general antes de que el autor invierta horas en los detalles y en los tests (lo de Fail Fast). Si el diseño está mal y te lo dicen al principio, cambiarlo cuesta poco. Si te lo dicen al final, ya has hecho todo el trabajo y además tiendes a defender un mal diseño por las horas que llevas metidas (la falacia del coste hundido). Al autor le parece que va más lento porque tiene que enseñar algo a medio hacer, pero al equipo le ahorra rehacer trabajo y rondas de revisión.

