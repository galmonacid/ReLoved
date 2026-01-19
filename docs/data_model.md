# Modelo de Datos (MVP)

## users/{uid}
Información básica del usuario.

Campos:
- displayName (string)
- email (string)
- createdAt (timestamp)
- ratingAvg (number, default 0)
- ratingCount (number, default 0)

Notas:
- No se almacenan datos personales adicionales en el MVP.
- Email solo se usa para contacto entre usuarios.

---

## items/{itemId}
Publicaciones de objetos disponibles.

Campos:
- ownerId (uid)
- title (string)
- photoUrl (string)
- createdAt (timestamp)
- status (string): available | reserved | given
- location:
  - lat (number)
  - lng (number)
  - geohash (string)
  - approxAreaText (string)

Notas:
- La ubicación es aproximada para preservar privacidad.
- El estado ayuda a reducir fricción incluso en el MVP.

---

## ratings/{ratingId}
Valoraciones simples tras un intercambio.

Campos:
- fromUserId (uid)
- toUserId (uid)
- itemId (string)
- stars (number: 1–5)
- createdAt (timestamp)

Notas:
- Las valoraciones se agregan en el perfil del usuario valorado.
- No hay comentarios escritos en el MVP.

---

## contactRequests/{id} (opcional)
Registro interno de contactos por email.

Campos:
- fromUserId (uid)
- toUserId (uid)
- itemId (string)
- message (string)
- createdAt (timestamp)
- sent (boolean)

Uso:
- Auditoría básica
- Prevención de abuso
