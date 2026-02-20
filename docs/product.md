# Producto (MVP)

## Visión
Crear una app que conecte a personas que quieren dar cosas que no necesitan con personas que las buscan, de forma sencilla, fomentando el cuidado del medio ambiente.

## Usuario objetivo
Personas concienciadas con el medio ambiente que:
- Quieren dar cosas que ya no usan.
- Quieren recibir cosas de segunda mano.

## Problema
Hoy estas interacciones se hacen en grupos de WhatsApp o Facebook:
- Las publicaciones se pierden rápidamente.
- No hay buscador intuitivo.
- La comunidad es pequeña y fragmentada.

## Propuesta de valor
Una app donde las personas pueden contactar de forma sencilla para dar cosas que no necesitan o encontrar algo que les hace falta de segunda mano.

## Core loop
1. Publicación de objeto: foto, título, descripción, postcode (UK), fecha automática.
2. Búsqueda: filtrado por radio (5 km / 20 km) + texto; orden por más recientes.
3. Contacto: formulario que envía email al dueño con mensaje libre.
4. Valoración: puntuación simple (1–5) tras un intercambio.

## Requisitos MVP
- Registro mínimo: email, contraseña, nombre visible.
- Publicación de objetos con foto y ubicación aproximada.
- Búsqueda por radio + texto.
- Contacto vía email (sin chat en la app).
- Valoraciones simples.

## Restricciones
- Sin pagos ni transacciones monetarias.
- Sin chat interno en MVP.
- Sin moderación avanzada.
- Sin login con Google o Apple en MVP.

## Alcance geográfico
- UK: entrada por postcode.
- Radio fijo: 5 km y 20 km.

## Plataforma objetivo
- Mobile (iOS y Android).

## Roadmap
### Fase 1: Registro y perfil
- Registro mínimo: email, contraseña, nombre visible.
- Inicio de sesión básico.

### Fase 2: Publicaciones de objetos
- Subir objeto con foto, título, descripción, postcode (UK) y fecha automática.
- Listado de objetos visibles según radio.

### Fase 3: Búsqueda
- Filtrado por radio: 5 km / 20 km.
- Búsqueda por texto (título + descripción).
- Orden por fecha de publicación.

### Fase 4: Contacto
- Formulario de mensaje libre que envía email automático al dueño del objeto.

### Fase 5: Valoraciones
- Valoración simple tras completar el intercambio.

### Fase 6: Lanzamiento MVP
- Probar con usuarios reales en un radio inicial reducido.
- Recoger feedback sobre usabilidad y valor del producto.

### Fase 7: Chat integrado (fast follower)
- Chat 1:1 entre dueño del objeto e interesado.
- Solo texto plano.
- Persistencia en Firestore.
- Sin indicadores de escritura ni estados avanzados.
- Email como fallback.
