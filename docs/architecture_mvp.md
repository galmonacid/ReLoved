# Arquitectura MVP

## Objetivo
Lanzar el MVP en el menor tiempo posible para validar el interés real de los usuarios, minimizando complejidad técnica y decisiones de infraestructura.

## Criterio principal
> Velocidad de desarrollo por encima de escalabilidad o sofisticación técnica.

## Stack tecnológico
- **App móvil**: Flutter (iOS y Android)
- **Autenticación**: Firebase Authentication (email / contraseña)
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
- Chat en tiempo real (fast follower)
- Notificaciones push
- Pagos
- Moderación avanzada
- Login social (Google / Apple)
- Escalado multi-región

## Evolución prevista (post-MVP)
- Añadir chat integrado usando Firestore (fast follower)
- Evaluar optimización de geo-búsqueda si el uso lo justifica
- Introducir notificaciones push si hay tracción
