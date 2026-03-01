# Chat Messaging Specification

## Scope
- Chat 1:1 entre owner de item e interesado.
- Conversacion vinculada a un item.
- Coexistencia con canal email segun `contactPreference` del item.

## Out of scope (fase actual)
- Push notifications.
- Adjuntos multimedia.
- Chat global user-to-user no vinculado a item.
- Moderacion automatica avanzada.

## Contact channel policy
- `items.contactPreference`:
  - `email`: solo formulario email.
  - `chat`: solo chat interno.
  - `both`: ambos canales.
- Legacy item sin campo: fallback cliente `both`.

## Conversation lifecycle
- Conversation id deterministico: `{itemId}_{interestedUserId}`.
- Estados:
  - `open`
  - `closed_by_owner`
  - `archived_item_unavailable`
  - `blocked`
- Reglas:
  - Owner puede cerrar/reabrir.
  - Si item pasa a `given` o se elimina, conversaciones se archivan.
  - En estados no `open`, chat queda en solo lectura.

## Firestore schema
- `conversations/{conversationId}` con metadata de item/participantes/unread/status.
- `conversations/{conversationId}/messages/{messageId}` con texto y metadatos de redaccion.
- `chatReports/{reportId}` para reportes de abuso.
- `chatRateLimits/{uid}` para control anti-spam.

## Backend callable APIs
- `upsertItemConversation({ itemId })`
- `sendChatMessage({ conversationId, text })`
- `markConversationRead({ conversationId })`
- `closeConversationByDonor({ conversationId })`
- `reopenConversationByDonor({ conversationId })`
- `setItemContactPreference({ itemId, contactPreference })`
- `blockConversationParticipant({ conversationId, blockedUserId })`
- `reportConversation({ conversationId, reason, details })`
- `anonymizeUserChatData({ targetUserId })` (admin)

## Security model
- Escrituras de chat via callable functions.
- Firestore rules:
  - `conversations` y `messages` lectura solo participantes.
  - `chatReports`, `chatRateLimits`, `contactRequests`: sin acceso cliente.
- Validaciones backend:
  - auth requerida
  - no self-contact
  - item disponible para crear chat
  - respeto de `contactPreference`
  - estado de conversacion
  - rate limit por usuario

## Abuse controls
- Rate limiting al enviar mensajes.
- Bloqueo manual por participante.
- Reporte manual con motivo.
- Logging estructurado en Cloud Functions.

## Retention and privacy
- Mensajes/reportes con politicas de retencion de 24 meses.
- Job programado redacta mensajes expirados y elimina reportes antiguos.
- Para account deletion, existe callable administrativa de anonimizado.

## App UX
- Bottom nav con sesion: `Search | Inbox | Publish | Profile`.
- Inbox muestra conversaciones por `lastMessageAt`.
- Thread muestra mensajes y estado read-only segun lifecycle.
- Item Detail muestra CTA de contacto segun `contactPreference`.

## Analytics events
- `contact_channel_selected`
- `chat_open`
- `chat_message_send`
- `chat_close`
- `chat_reopen`
- `chat_block`
- `chat_report`

## Operational notes
- Rules tests requieren Firebase emulator disponible.
- `firebase emulators:exec` requiere Java 21+ en entorno local/CI.
