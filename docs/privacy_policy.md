# Politica de Privacidad (MVP)

Ultima actualizacion: 2026-03-04

## Resumen
ReLoved recopila la informacion minima necesaria para operar el servicio
(cuentas, publicaciones, mensajes de contacto por email y mensajes de chat).
No vendemos datos personales.

## Datos que recopilamos
- Cuenta: email, nombre visible y UID.
- Contenido: publicaciones (titulo, descripcion, foto, ubicacion aproximada).
- Contacto por email: metadatos y contenido de `contactRequests`.
- Chat interno: conversaciones y mensajes de texto vinculados a items.
- Soporte monetario (opcional): estado de suscripcion, customer id de Stripe y eventos de pago.
- Uso: eventos basicos de analitica para mejorar el producto.

## Como usamos los datos
- Autenticacion y acceso a la app.
- Publicacion y descubrimiento de items.
- Contacto entre usuarios sobre un item por email o chat.
- Prevencion de abuso (rate limiting, bloqueo, reportes).
- Mejora del producto (analitica agregada).
- Gestion de donaciones y suscripciones opcionales.
- Aplicacion de limites soft de uso (publicar/contactar) con opcion de continuar gratis.

## Comparticion de datos
- En canal email, el email del remitente se comparte con el propietario del item.
- En chat interno no se expone el email por defecto.
- Proveedores de infraestructura: Firebase, SendGrid y Stripe.

## Retencion
Ver `docs/data_retention.md`.

## Pagos y soporte opcional
- Los pagos se procesan mediante Stripe; ReLoved no almacena datos completos de tarjeta.
- Una donacion puntual no cambia automaticamente los limites funcionales.
- La suscripcion mensual puede ampliar limites de uso mientras este activa segun la politica del producto.

## Eliminacion de cuenta
El usuario puede solicitar eliminacion a soporte (ver perfil en la app).
Parte de la limpieza/anonimizacion de datos de chat se realiza de forma
manual en esta fase.

## Cambios
Este documento puede actualizarse; se notificara en la app cuando aplique.
