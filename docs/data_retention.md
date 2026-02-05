# Data Retention y Eliminacion de Cuenta (MVP)

Ultima actualizacion: 2026-02-05

## Retencion
- Cuentas y publicaciones se conservan mientras la cuenta este activa.
- Logs tecnicos y eventos de analitica se conservan hasta 12 meses.
- Solicitudes de contacto se conservan hasta 24 meses para soporte.

## Eliminacion de cuenta
- El usuario solicita la eliminacion desde la app (Perfil -> eliminar cuenta).
- Se elimina:
  - Documento de usuario en Firestore.
  - Publicaciones del usuario.
  - Fotos en Storage asociadas a sus items.
- Se anonimiza:
  - Registros historicos de contacto (se remueve el email).
  - Ratings (se conserva el valor agregado sin identificador).

## Plazos
- Eliminacion en un plazo maximo de 30 dias tras la solicitud.

> Este proceso es manual en MVP. Puede automatizarse en versiones futuras.
