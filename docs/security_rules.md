# Principios de Seguridad (MVP)

## Principios generales
- Navegacion publica para lectura de items.
- Autenticacion requerida para publicar y contactar.
- Cada usuario solo puede modificar sus propios recursos cuando aplica.
- Para chat, la lectura es solo para participantes y la escritura sensible pasa por Cloud Functions.
- La seguridad se apoya en reglas Firestore + validaciones en backend.

---

## Reglas por coleccion (conceptual)

### users
- Lectura:
  - Permitida para usuarios autenticados (campos publicos).
- Escritura:
  - Solo el propio usuario puede crear o modificar su documento.

### items
- Lectura:
  - Publica (sin autenticacion).
- Escritura:
  - Crear: usuario autenticado con `ownerId == auth.uid`.
  - Modificar/borrar: solo owner del item.
  - `contactPreference` validado como `email | chat | both`.

### ratings
- Lectura:
  - Permitida para usuarios autenticados.
- Escritura:
  - Solo usuarios autenticados.
  - `fromUserId` debe coincidir con `auth.uid`.
  - stars entre 1 y 5.

### contactRequests
- Lectura/escritura cliente:
  - Denegada.
- Escritura:
  - Solo mediante Cloud Function `sendContactEmail`.

### conversations
- Lectura:
  - Solo participantes (`auth.uid in participants`).
- Escritura cliente:
  - Denegada.
- Escritura backend:
  - Solo Cloud Functions (`upsertItemConversation`, `close/reopen`, `block`, `markConversationRead`, archivado automatico).

### conversations/{id}/messages
- Lectura:
  - Solo participantes de la conversacion padre.
- Escritura cliente:
  - Denegada.
- Escritura backend:
  - Solo Cloud Function `sendChatMessage`.

### chatReports
- Lectura/escritura cliente:
  - Denegada.
- Escritura backend:
  - Solo Cloud Function `reportConversation`.

### chatRateLimits
- Lectura/escritura cliente:
  - Denegada.
- Escritura backend:
  - Solo Cloud Function `sendChatMessage`.

---

## Cloud Functions (controles)
- Validan autenticacion y permisos de rol/owner.
- Aplican reglas de negocio de chat:
  - item disponible para crear hilo.
  - self-contact no permitido.
  - preferencias de contacto del donor.
  - estado de conversacion (`open`, `closed`, `archived`, `blocked`).
- Aplican rate limiting anti-spam.
- Ejecutan archivado de conversaciones cuando item deja de estar disponible.
- Ejecutan retencion/redaccion periodica de mensajes/reportes.

---

## Supuestos operativos
- Comunidad pequena y de buena fe.
- Moderacion avanzada fuera de alcance en esta fase.
- Reportes y anonimizacion administrativa se operan manualmente al inicio.
