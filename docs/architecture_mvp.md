# Arquitectura MVP

## Objetivo
Lanzar el MVP en el menor tiempo posible para validar el interés real de los usuarios, minimizando complejidad técnica y decisiones de infraestructura.

## Criterio principal
> Velocidad de desarrollo por encima de escalabilidad o sofisticación técnica.

## Stack tecnológico
- **App móvil**: Flutter (iOS y Android)
- **Autenticación**: Firebase Authentication (email/password + Google en iOS/Web + Apple en iOS)
- **Base de datos**: Cloud Firestore
- **Almacenamiento de imágenes**: Firebase Storage
- **Backend serverless**: Cloud Functions (TypeScript)
- **Email transaccional**: SendGrid o Mailgun
- **Analytics y errores**: Firebase Analytics + Crashlytics
- **Geocoding UK**: postcodes.io (MVP)

## Principios arquitectónicos
- Backend mínimo
- Serverless-first
- Lecturas directas desde cliente cuando sea posible
- Lógica compleja solo en Cloud Functions
- No optimizar prematuramente para escala

## Búsqueda por ubicación
- Uso de `lat / lng` + `geohash`
- Filtros por radio fijo (3 mi / 10 mi)
- Query por prefijos de geohash + filtrado por distancia real
- Orden por fecha de publicación (más recientes primero)
- Entrada de ubicación por postcode en UK (normalizado)

## Fuera de alcance del MVP
- Notificaciones push para chat
- Adjuntos multimedia en chat
- Pagos
- Moderación avanzada
- Escalado multi-región

## Scope de autenticación social (release actual)
- Google login habilitado en iOS y Web.
- Sign in with Apple habilitado solo en iOS.
- Android permanece fuera de alcance para login social en esta iteración (sin configuración OAuth Android activa).
- Se mantiene política de una cuenta por email:
  - Si el email ya existe con otro método, se ejecuta flujo de account linking.
  - El objetivo es evitar duplicados de usuario por proveedor.

## Evolución prevista (post-MVP)
- Añadir push notifications para inbox/chat si hay tracción
- Evaluar optimización de geo-búsqueda si el uso lo justifica
- Introducir moderación automática para reportes de chat
