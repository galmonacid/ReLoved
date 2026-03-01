# Data Retention y Eliminacion de Cuenta (MVP)

Ultima actualizacion: 2026-03-01

## Retencion
- Cuentas y publicaciones: mientras la cuenta este activa.
- Logs tecnicos y eventos de analitica: hasta 12 meses.
- Solicitudes de contacto por email (`contactRequests`): hasta 24 meses para soporte.
- Mensajes de chat:
  - Conversaciones y mensajes activos: mientras exista relacion operativa del item.
  - Redaccion por retencion: mensajes antiguos se redactan tras 24 meses.
- Reportes de chat (`chatReports`): eliminacion tras 24 meses.

## Eliminacion de cuenta
- El usuario solicita la eliminacion desde la app/perfil (flujo de soporte).
- Se elimina:
  - Documento de usuario en Firestore.
  - Publicaciones del usuario.
  - Fotos en Storage asociadas a sus items.
- Se anonimiza:
  - Registros historicos de contacto email (se remueve email).
  - Mensajes/hilos de chat asociados al usuario (redaccion y `senderId` anonimizado).
  - Ratings (se conserva valor agregado sin identificador personal).

## Plazos
- Eliminacion completa en maximo 30 dias desde solicitud.

## Operacion
- Parte del proceso sigue siendo manual (MVP).
- Existen utilidades backend para anonimizar datos de chat cuando soporte lo requiera.
