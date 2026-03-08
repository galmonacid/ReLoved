# Monetization Stripe Spec

Ultima actualizacion: 2026-03-04

## Objetivo
Monetizacion opcional en ReLoved sin bloquear el uso core:
- Donacion puntual GBP 3.
- Suscripcion mensual GBP 4.99.
- Soft paywall en limites de publicar/contactar, con opcion de continuar gratis.

## Reglas de producto

### Limites free
- Publicar: maximo 3 items activos (`available` o `reserved`).
- Contactar: maximo 10 nuevos items contactados por semana.
- Semana fiscal: lunes 00:00 en `Europe/London`.

### Suscripcion mensual
- "Ilimitado" comercial.
- Fair use tecnico:
  - max 200 items activos
  - max 250 nuevos contactos/semana

### Donacion puntual
- No concede perks funcionales.
- Se registra como apoyo voluntario.

### Principio UX
- El usuario siempre puede elegir `Continue without paying`.
- Si Stripe no esta disponible, no se bloquea el flujo principal.

## Modelo de datos
- `monetizationProfiles/{uid}`
- `billingCustomers/{uid}`
- `usageCounters/{uid}`
- `usageContactEvents/{uid_weekKey_itemId}`
- `stripeWebhookEvents/{eventId}`
- `runtimeConfig/monetization`

Campos base en `users/{uid}`:
- `supportTier`
- `supportStatus`
- `supportPeriodEnd`

## Cloud Functions

### Callables
- `getMonetizationStatus()`
- `createSupportCheckoutSession({ planType, source, successUrl, cancelUrl })`
- `createBillingPortalSession({ returnUrl })`

### HTTP webhook
- `stripeWebhook`
- valida firma Stripe
- procesa:
  - `checkout.session.completed`
  - `invoice.paid`
  - `invoice.payment_failed`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
- idempotencia por `stripeWebhookEvents/{eventId}`

## Integracion app Flutter
- Antes de publicar: consulta `getMonetizationStatus`.
- Antes de contactar (chat/email): consulta `getMonetizationStatus`.
- Si excede limite: mostrar soft paywall.
- Opciones del paywall:
  - Donate GBP 3
  - Subscribe GBP 4.99/month
  - Continue without paying

Pantallas:
- `About & Support` en Profile.

## Configuracion requerida

### Functions config
- `stripe.secret_key`
- `stripe.webhook_secret`
- `stripe.price_one_off_gbp_300`
- `stripe.price_monthly_gbp_499`

### Dart defines
- `STRIPE_PUBLISHABLE_KEY`
- `PAYMENTS_ENABLED_IOS`
- `PAYMENTS_ENABLED_WEB`

### Runtime config (Firestore)
Documento: `runtimeConfig/monetization`

Campos:
- `flags.monetizationEnabled` (bool)
- `flags.supportUiEnabled` (bool)
- `flags.checkoutEnabled` (bool)
- `flags.enforcePublishLimit` (bool)
- `flags.enforceContactLimit` (bool)
- `thresholds.free.publishLimit` (int)
- `thresholds.free.contactLimit` (int)
- `thresholds.supporter.publishLimit` (int)
- `thresholds.supporter.contactLimit` (int)
- `window.timeZone` (IANA, default `Europe/London`)
- `window.weekStartIsoDay` (1..7, default `1`)

Defaults backend (si falta config o hay valores invalidos):
- Todos los flags en `false` (fail-open en flows core).
- Limites `free=3/10`, `supporter=200/250`.
- Ventana semanal `Europe/London`, lunes.

## Seguridad
- Cliente no escribe datos de billing/usage.
- Reglas Firestore deniegan acceso cliente a:
  - `billingCustomers`
  - `stripeWebhookEvents`
  - `usageContactEvents`
- Lectura del propio estado permitida en:
  - `monetizationProfiles/{uid}`
  - `usageCounters/{uid}`

## Observabilidad
Eventos de analytics:
- `about_support_opened`
- `paywall_shown`
- `paywall_continue_free`
- `support_checkout_started`
- `support_checkout_success`
- `support_checkout_cancel`
- `support_subscription_state_changed`

## Rollout recomendado
1. Deploy functions + rules + app (con soporte de runtime config).
2. Crear `runtimeConfig/monetization` con preset `all-off`.
3. Configurar secretos Stripe en prod.
4. Activar progresivamente:
   - `supportUiEnabled`
   - `enforcePublishLimit` / `enforceContactLimit`
   - `checkoutEnabled`
5. Monitorizar errores y conversion.

Rollback rapido:
- poner todos los flags en `false` (sin redeploy).

Script de operacion:
- `node scripts/monetization/set_runtime_config.cjs show`
- `node scripts/monetization/set_runtime_config.cjs preset all-off`
- `node scripts/monetization/set_runtime_config.cjs preset limits-on`
- `node scripts/monetization/set_runtime_config.cjs preset full-on`
