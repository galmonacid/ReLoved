# Modelo de Datos (MVP)

## users/{uid}
Informacion basica del usuario.

Campos:
- displayName (string)
- email (string)
- createdAt (timestamp)
- ratingAvg (number, default 0)
- ratingCount (number, default 0)

Notas:
- No se almacenan datos personales adicionales en el MVP.
- Email se usa para auth y para contacto por canal email.

---

## items/{itemId}
Publicaciones de objetos disponibles.

Campos:
- ownerId (uid)
- title (string)
- description (string, opcional)
- photoUrl (string)
- photoPath (string, opcional)
- createdAt (timestamp)
- updatedAt (timestamp, opcional)
- status (string): available | reserved | given
- contactPreference (string): email | chat | both
- location:
  - lat (number)
  - lng (number)
  - geohash (string)
  - approxAreaText (string)

Notas:
- Si `contactPreference` no existe (items legacy), el cliente usa fallback `both`.
- La ubicacion es aproximada para preservar privacidad.
- En UK, approxAreaText almacena el postcode mostrado al usuario.
- description se usa para busqueda por palabras.

---

## conversations/{conversationId}
Conversaciones 1:1 vinculadas a item.

Campos:
- itemId (string)
- itemTitle (string)
- itemPhotoUrl (string)
- itemApproxArea (string)
- ownerId (uid)
- interestedUserId (uid)
- participants (array<string>, 2 elementos)
- status (string): open | closed_by_owner | archived_item_unavailable | blocked
- createdAt (timestamp)
- updatedAt (timestamp)
- lastMessageAt (timestamp, opcional)
- lastMessageSenderId (uid, opcional)
- lastMessagePreview (string, opcional)
- ownerUnreadCount (number)
- interestedUnreadCount (number)
- closedBy (uid, opcional)
- closedAt (timestamp, opcional)
- reopenedAt (timestamp, opcional)
- blockedByUserId (uid, opcional)
- blockedAt (timestamp, opcional)

Regla de unicidad:
- 1 hilo por `itemId + interestedUserId`.

---

## conversations/{conversationId}/messages/{messageId}
Mensajes de una conversacion.

Campos:
- senderId (uid | anonymized)
- text (string)
- createdAt (timestamp)
- isRedacted (boolean)
- redactedAt (timestamp, opcional)
- redactionReason (string, opcional): account_deleted | retention_expired

Notas:
- Solo texto en esta fase (sin adjuntos).

---

## chatReports/{reportId}
Reportes de abuso en chat.

Campos:
- conversationId (string)
- itemId (string)
- reporterUserId (uid)
- reportedUserId (uid)
- reason (string): spam | inappropriate | harassment | other
- details (string, opcional)
- createdAt (timestamp)
- status (string): open | reviewed | closed

Uso:
- Soporte y moderacion manual.

---

## chatRateLimits/{uid}
Estado de rate limiting por usuario para envio de chat.

Campos:
- lastMessageAt (timestamp)
- minuteWindowStart (timestamp)
- minuteCount (number)
- updatedAt (timestamp)

Uso:
- Limitar spam en chat.

---

## ratings/{ratingId}
Valoraciones simples tras un intercambio.

Campos:
- fromUserId (uid)
- toUserId (uid)
- itemId (string)
- stars (number: 1-5)
- createdAt (timestamp)

---

## contactRequests/{id}
Registro interno de contactos por email.

Campos:
- fromUserId (uid)
- fromEmail (string)
- toUserId (uid)
- toEmail (string)
- itemId (string)
- itemTitle (string)
- itemStatus (string)
- itemApproxArea (string)
- subject (string)
- message (string)
- createdAt (timestamp)
- sentAt (timestamp, opcional)
- sent (boolean)
- error (string, opcional)
- channel (string): email
- contactPreference (string): email | chat | both

Uso:
- Auditoria basica
- Prevencion de abuso
