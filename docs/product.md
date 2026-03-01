# Producto (MVP+)

## Vision
Crear una app que conecte a personas que quieren dar cosas que no necesitan con personas que las buscan, de forma sencilla, fomentando el cuidado del medio ambiente.

## Usuario objetivo
Personas concienciadas con el medio ambiente que:
- Quieren dar cosas que ya no usan.
- Quieren recibir cosas de segunda mano.

## Problema
Hoy estas interacciones se hacen en grupos de WhatsApp o Facebook:
- Las publicaciones se pierden rapidamente.
- No hay buscador intuitivo.
- La comunidad es pequena y fragmentada.

## Propuesta de valor
Una app donde las personas publican objetos y se ponen en contacto de forma simple por email o chat interno segun la preferencia del donor.

## Core loop
1. Publicacion de objeto: foto, titulo, descripcion, postcode (UK), fecha automatica.
2. Busqueda: filtrado por radio (3 mi / 10 mi) + texto; orden por mas recientes.
3. Contacto: canal por item (`email`, `chat` o `both`) definido por el donor.
4. Valoracion: puntuacion simple (1-5) tras un intercambio.

## Requisitos MVP actual
- Registro minimo: email, contrasena, nombre visible.
- Publicacion de objetos con foto y ubicacion aproximada.
- Busqueda por radio + texto.
- Contacto por email y/o chat segun preferencia del donor.
- Inbox de conversaciones para usuarios autenticados.
- Valoraciones simples.

## Restricciones
- Sin pagos ni transacciones monetarias.
- Chat solo 1:1 y vinculado a item (no chat global entre usuarios).
- Sin adjuntos multimedia en chat (solo texto).
- Sin moderacion avanzada en esta fase (solo bloqueos/reportes basicos).
- Sin login con Google o Apple en MVP.

## Alcance geografico
- UK: entrada por postcode.
- Radio fijo: 3 mi y 10 mi.

## Plataforma objetivo
- Mobile (iOS y Android).

## Decision de contacto
- El donor decide por item:
  - `email`: solo formulario email.
  - `chat`: solo chat interno.
  - `both`: chat + email.
- Para items legacy sin campo `contactPreference`, default de runtime: `both`.

## Ciclo de vida del chat
- Hilo unico por `item + interesado`.
- El donor puede cerrar y reabrir el chat.
- Si item pasa a `given` o se elimina, las conversaciones se archivan en modo solo lectura.

## Roadmap
### Fase 1: Registro y perfil
- Registro minimo: email, contrasena, nombre visible.
- Inicio de sesion basico.

### Fase 2: Publicaciones de objetos
- Subir objeto con foto, titulo, descripcion, postcode (UK) y fecha automatica.
- Listado de objetos visibles segun radio.

### Fase 3: Busqueda
- Filtrado por radio: 3 mi / 10 mi.
- Busqueda por texto (titulo + descripcion).
- Orden por fecha de publicacion.

### Fase 4: Contacto
- Email via Cloud Function con auditoria.
- Chat interno por item, con inbox y estados open/closed/archived.

### Fase 5: Valoraciones
- Valoracion simple tras completar el intercambio.

### Fase 6: Lanzamiento MVP
- Probar con usuarios reales en un radio inicial reducido.
- Recoger feedback sobre usabilidad y valor del producto.

### Fase 7: Mejoras posteriores
- Push notifications de nuevos mensajes.
- Moderacion avanzada.
- Adjuntos multimedia en chat.
