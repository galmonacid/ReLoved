# Roadmap del MVP

## Objetivo
Lanzar una versión mínima funcional que permita validar la idea de negocio con el menor esfuerzo posible.

## Ejecución
- Plan detallado: `docs/execution_plan.md`

## Cómo arrancar rápido (comandos)
Desde la raíz del repo:
```bash
cd app
flutter create .
cd ..
dart pub global activate flutterfire_cli
flutterfire configure
```

Luego para desplegar backend (rules/indexes/functions):
```bash
firebase login
firebase init firestore storage functions
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

## Fases

### Fase 1: Registro y perfil
- Crear registro mínimo: email, contraseña, nombre visible.
- Inicio de sesión básico.

### Fase 2: Publicaciones de objetos
- Permitir subir objeto con foto, título, ubicación y fecha automática.
- Listado de objetos visibles según radio.

### Fase 3: Búsqueda
- Implementar búsqueda filtrada por radio: 5 km / 20 km.
- Ordenar por fecha de publicación.

### Fase 4: Contacto
- Formulario de mensaje libre que envía email automático al dueño del objeto.

### Fase 5: Valoraciones
- Permitir dejar una valoración simple tras completar el intercambio.

### Fase 6: Lanzamiento MVP
- Probar con usuarios reales en un radio inicial reducido.
- Recoger feedback sobre usabilidad y valor del producto.

### Fase 7: Chat integrado (Fast Follower)
- Chat 1:1 entre dueño del objeto e interesado.
- Solo texto plano.
- Persistencia en Firestore.
- Sin indicadores de escritura ni estados avanzados.
- El email queda como fallback.
