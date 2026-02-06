# UX y flujos (MVP)

## Direccion visual
- Paleta principal: blanco + verde sage (acentos, botones y elementos destacados).

## Pantallas
- Auth: Registro, Login.
- Buscar: lista de items + filtro de radio (5 km / 20 km) + buscador por palabras (publico).
- Publicar: formulario con foto, titulo, descripcion, ubicacion aproximada y pin de mapa.
- Detalle de item: foto, titulo, distancia aprox, estado y CTA de contacto.
- Contacto: formulario de mensaje y confirmacion de envio.
- Perfil: displayName, rating promedio, cerrar sesion.
- Perfil (legal): enlaces a politica de privacidad, terminos y solicitud de eliminacion.
- Valorar: selector 1-5 estrellas accesible desde detalle cuando el item esta en "given".

## Navegacion
- Barra inferior con 3 tabs: Buscar, Publicar, Perfil.
- Detalle se abre desde Buscar o desde "Mis items" si se agrega luego.

## Flujos
### Registro / login
1. App inicia -> determina estado de sesion.
2. Usuario puede navegar sin sesion.
3. Usuario nuevo: Registro (email, password, displayName).
4. Usuario existente: Login.
5. Success -> Buscar / Publicar.

### Publicar item
1. Tab Publicar -> requiere login.
2. Elegir ubicacion con pin y completar titulo + descripcion + area aproximada.
3. Crear item -> navegar a Detalle del item.

### Buscar y ver item
1. Tab Buscar -> seleccionar radio (5 km / 20 km) y/o texto de busqueda.
2. Lista ordenada por mas recientes.
3. Tap en item -> Detalle.

### Contacto
1. En Detalle -> CTA "Contactar".
2. Si no hay sesion, solicitar login.
3. Formulario mensaje -> enviar.
4. Mostrar confirmacion.

### Valorar
1. Cuando un intercambio se considera completado, el item pasa a "given".
2. En Detalle -> CTA "Valorar" -> selector 1-5 estrellas.
