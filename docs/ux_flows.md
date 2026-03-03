# UX y flujos (MVP)

## Direccion visual
- Paleta principal: blanco + verde sage (acentos, botones y elementos destacados).

## Pantallas
- Auth: Registro, Login.
- Buscar: lista de items + filtro de radio (3 mi / 10 mi) + buscador por palabras (publico).
- Inbox: lista de conversaciones de chat para usuarios autenticados.
- Chat thread: mensajes 1:1 vinculados a un item.
- Publicar: formulario con foto, titulo, descripcion, postcode (UK), pin de mapa y preferencia de contacto.
- Detalle de item: foto, titulo, distancia aprox, estado y CTA de contacto segun `contactPreference`.
- Contacto email: formulario y confirmacion de envio.
- Perfil: displayName, rating promedio, cerrar sesion.
- Perfil (legal): enlaces a politica de privacidad, terminos y solicitud de eliminacion.
- Valorar: selector 1-5 estrellas accesible desde detalle cuando el item esta en "given".

## Navegacion
- Sin sesion: barra inferior con 2 tabs: Buscar, Sign in.
- Con sesion: barra inferior con 4 tabs: Buscar, Inbox, Publicar, Perfil.
- Detalle se abre desde Buscar o desde "Mis items".
- Chat thread se abre desde Inbox o desde Detalle (CTA chat).

## Flujos
### Registro / login
1. App inicia -> determina estado de sesion.
2. Usuario puede navegar sin sesion.
3. Usuario nuevo: Registro (email, password, displayName).
4. Usuario existente: Login.
5. Opciones sociales:
   - Google en iOS y Web.
6. Si el email ya existe con otro proveedor:
   - se activa flujo de account linking;
   - en caso de cuenta password, se solicita password para vincular.
7. Success -> Buscar / Inbox / Publicar / Perfil.

### Publicar item
1. Tab Publicar -> requiere login.
2. Buscar postcode y/o ajustar pin en el mapa.
3. Completar titulo + descripcion + approx area.
4. Seleccionar preferencia de contacto (`email`, `chat`, `both`).
5. Crear item -> navegar a Detalle del item.

### Buscar y ver item
1. Tab Buscar -> seleccionar radio (3 mi / 10 mi) y/o texto de busqueda.
2. Lista ordenada por mas recientes.
3. Tap en item -> Detalle.

### Contacto por item
1. En Detalle, si usuario no es owner:
   - `email`: CTA "Contact by email".
   - `chat`: CTA "Open chat".
   - `both`: CTA principal chat + accion secundaria email.
2. Si no hay sesion, solicitar login.
3. Contacto email:
   - Formulario mensaje -> enviar -> confirmacion.
4. Contacto chat:
   - Crear/abrir conversacion unica por item + interesado.
   - Enviar mensajes en thread.

### Inbox + chat
1. Tab Inbox -> lista de conversaciones del usuario.
2. Tap en conversacion -> thread.
3. Al abrir thread -> se marcan mensajes como leidos.
4. Estados:
   - `open`: envio habilitado.
   - `closed_by_owner`: solo lectura, owner puede reabrir.
   - `archived_item_unavailable`: solo lectura.
   - `blocked`: solo lectura.
5. Acciones:
   - Owner: cerrar / reabrir.
   - Ambos: bloquear otro usuario, reportar conversacion.

### Estado de item y chat
1. Si item pasa a `given` o se elimina:
   - conversaciones vinculadas se archivan.
   - no se pueden crear nuevas conversaciones para ese item.

### Valorar
1. Cuando un intercambio se considera completado, el item pasa a "given".
2. En Detalle -> CTA "Valorar" -> selector 1-5 estrellas.
