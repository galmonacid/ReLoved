# Core Loop del MVP

## Objetivo
Permitir que los usuarios publiquen objetos, busquen objetos disponibles y contacten de forma sencilla.

## 1. Publicación de objeto
- Usuario pulsa “Publicar”.
- Campos obligatorios: foto, título, descripción, postcode (UK) y fecha automática.
- Objeto visible para usuarios dentro del radio seleccionado.

## 2. Búsqueda de objetos
- Usuario pulsa “Buscar”.
- Objetos filtrados por radio (5 km / 20 km).
- Ordenados por fecha de publicación (más recientes primero).

## 3. Contacto entre usuarios (MVP)
- Usuario pulsa “Contactar” y completa un formulario con mensaje libre.
- La app envía un email automático al dueño del objeto con:
  - Mensaje del interesado
  - Email del interesado
- El dueño responde directamente desde su correo.

## 4. Valoración de usuarios
- Tras completar un intercambio, cada usuario puede dejar una valoración simple (1–5 estrellas).
- No hay historial de mensajes dentro de la app.

## Evolución post-MVP
- Sustituir el email por chat integrado dentro de la app.
- Mantener email como fallback.
