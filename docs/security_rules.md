# Principios de Seguridad (MVP)

## Principios generales
- Navegación pública para lectura de items.
- Autenticación requerida para publicar y contactar.
- Cada usuario solo puede modificar sus propios recursos.
- La lectura es más permisiva que la escritura.
- La seguridad se apoya en reglas Firestore + validaciones en Cloud Functions.

---

## Reglas por colección (conceptual)

### users
- Lectura:
  - Permitida para usuarios autenticados (campos públicos).
- Escritura:
  - Solo el propio usuario puede crear o modificar su documento.

---

### items
- Lectura:
  - Pública (sin autenticación).
- Escritura:
  - Crear: usuario autenticado.
  - Modificar / borrar: solo el ownerId del item.

---

### ratings
- Lectura:
  - Permitida para usuarios autenticados (por ahora).
- Escritura:
  - Solo usuarios autenticados.
  - El `fromUserId` debe coincidir con el usuario autenticado.
  - No se permite valorar varias veces el mismo intercambio.

---

### contactRequests
- Escritura:
  - Solo mediante Cloud Function.
- Lectura:
  - No accesible desde cliente.

---

## Cloud Functions
- Validan autenticación
- Aplican rate limiting (anti-spam)
- Protegen credenciales de servicios externos (email)

---

## Supuestos del MVP
- Comunidad pequeña y de buena fe
- No se implementa detección avanzada de fraude
- Se prioriza simplicidad sobre control exhaustivo
