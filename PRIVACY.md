# Privacidad de Menú y Qué ver

Última actualización: 9 de noviembre de 2026

## Datos locales y servicios externos

Las apps nativas guardan sus ajustes y datos en el almacenamiento del iPhone. No incluyen analítica, publicidad ni servidores propios para recopilar tus listas. Eso no significa que todas sus funciones sean sin conexión: las consultas descritas abajo envían datos a servicios externos, que reciben también información técnica de la conexión, como la dirección IP.

Las claves que introduces se guardan en el dispositivo. No forman parte del código del repositorio ni se incluyen en las exportaciones de listas o menús. Las apps no suministran una clave compartida ni activan facturación. No compartas tus claves ni las incluyas en capturas, incidencias o archivos públicos.

## Menú

Los platos, ingredientes, menús, historial, preferencias aprendidas y lista de compra se guardan localmente. El widget lee el menú mediante un contenedor compartido de la app y su extensión en el iPhone.

### Gemini API, opcional

Sin clave, el generador usa las reglas locales y no consulta Gemini. Si introduces tu propia clave y usas la IA:

- Para rellenar ingredientes se envía a Google el nombre del plato y las instrucciones de la consulta.
- Para generar un menú se envían los platos disponibles con sus identificadores, categorías, momentos y límites, la estación, los turnos fijados y un resumen de platos recientes y preferencias aprendidas. No se envía la base de datos completa como archivo.
- Probar la clave consulta la lista de modelos y puede realizar una consulta de prueba a Google.
- La clave se transmite a Google para autenticar las peticiones. Las respuestas se procesan en la app y pueden guardarse como ingredientes o menú.

## Qué ver

Las colecciones de pendientes, vistas, temporadas y sus marcas se guardan en el dispositivo.

### Catálogo e imágenes

Buscar, abrir fichas y cargar rankings consulta JustWatch; se envían el título o identificador y los filtros necesarios, como país, plataforma y tipo. Las imágenes se descargan de sus servidores. El acceso técnico a un endpoint no acredita permiso para usar o redistribuir su contenido. La revisión de licencia de esta integración sigue pendiente; esta política no constituye una autorización del proveedor.

Cuando falta una nota IMDb, la app puede consultar el servicio OMDb mediante el proxy de la web del proyecto o directamente con una clave propia. Esa consulta envía el identificador IMDb, no tus listas completas. El proxy y OMDb reciben la información técnica de la conexión correspondiente.

### Gemini API, opcional

Sin clave no se llama a Gemini. Con una clave propia:

- Se envían a Google la descripción que escribes y las instrucciones para proponer títulos.
- La revisión de candidatos puede enviar también datos de las fichas necesarias para valorar si encajan con la descripción, como título, año, géneros y sinopsis.
- Guardar o comprobar la clave consulta los modelos disponibles en Google.
- La clave se transmite a Google para autenticar las consultas.

Pegar una respuesta obtenida por tu cuenta no la envía completa a Gemini: se analiza en el iPhone y los títulos detectados se consultan en el catálogo. El servicio de IA que hayas usado por tu cuenta tiene sus propias condiciones.

### Importar y exportar

Las exportaciones generan un archivo que tú eliges dónde guardar o compartir. Al importar desde la web se descarga su instantánea disponible; no se sube la lista local ni se sincronizan automáticamente los cambios. Los servicios usados para alojar o compartir esos archivos tienen sus propias políticas.

## Condiciones y tratamiento de Google

La IA es opcional y usa la cuenta y clave del usuario. Cada usuario responde del uso de su cuenta y debe comprobar los términos, restricciones regionales, cuotas y posibles costes aplicables. Tener una clave propia o aceptar un aviso no garantiza que el uso esté permitido ni sea gratuito.

Los términos consultados el 9 de noviembre de 2026 indican que los clientes API ofrecidos a usuarios en el EEE, Suiza y Reino Unido deben usar Paid Services. Esta app no activa facturación ni afirma que una cuenta sin facturación cumpla esa condición. Google puede limitar o suspender el acceso conforme a sus términos. No introduzcas información sensible o confidencial en las consultas.

El tratamiento y la conservación de consultas, respuestas e información técnica por Google dependen del servicio, la región y la cuenta. No prometemos que Google no guarde las consultas.

- Términos de Gemini API: https://aistudio.google.com/docs/terms
- Privacidad de Google: https://policies.google.com/privacy

## Control y eliminación

Puedes quitar tu clave en Ajustes para desactivar las llamadas a Gemini y borrar o exportar tus datos con las opciones de cada app. Desinstalar elimina el almacenamiento local de la app, pero no borra archivos exportados, copias de seguridad ni datos que un proveedor externo conserve. La revocación de una clave o las solicitudes a proveedores se gestionan en sus servicios.

## Contacto

El proyecto se mantiene en https://github.com/Pradaxa/menu-semanal . Para dudas sobre la app puedes abrir una incidencia sin publicar claves, listas ni otros datos privados. Esta política describe las apps nativas, no sustituye las políticas de las webs ni las de los proveedores externos.
