# Design System — Calm Marketplace (Sage)

## Core Philosophy

Premium calm. Clean surfaces. Strong hierarchy.
Less borders. More depth. Subtle motion.

If in doubt:
- Remove the border.
- Add spacing.
- Use surface instead of outline.
- Let primary actions be solid.

---

# Visual Principles

## 1. Reduce visual noise
- Avoid thin grey borders when spacing can solve separation.
- Prefer surface contrast (background shades) over outlines.
- Use dividers sparingly.

## 2. Solid over outline
- Primary actions must always be solid.
- Outline buttons only for clearly secondary actions.
- Avoid stacking multiple outlined buttons vertically.

## 3. Elevation & surfaces
- Use subtle elevation for cards.
- Prefer layered surfaces (white on sageSoft).
- Avoid flat grey screens.

## 4. Motion is part of polish
Micro-animations must be subtle and fast.

Use:
- Fade-in for cards (150–250ms)
- Slight scale on button press (0.98)
- Smooth tab transitions
- EaseInOut curves

Never:
- Bounce
- Long animations
- Heavy motion

---

# Color tokens (Light)

## Brand
- primary: #2F6B3F
- onPrimary: #FFFFFF

## Sage identity
- sage: #9CAF88
- sageSoft: #EEF1EA

## Neutrals
- bg: #FFFFFF
- text: #111827
- textBody: #374151
- textMuted: #6B7280
- border: #E5E7EB

## States
- success: #1E7F5C
- warning: #B45309
- error: #B42318
- info: #2563EB

---

# Typography

Font family: Inter

Weights:
- Regular: 400
- Medium: 500
- SemiBold: 600

Scale:
- Display: 28 / 32 (SemiBold)
- H1: 22 / 28 (SemiBold)
- H2: 18 / 24 (SemiBold)
- Body: 16 / 24 (Regular)
- Caption: 13 / 18 (Regular)

Text color hierarchy:
- Titles: text
- Body: textBody
- Meta / hint: textMuted

---

# Spacing (8pt grid)

- xs: 8
- sm: 12
- md: 16
- lg: 24
- xl: 32

Never use random spacing values.

---

# Radius

- card/input/button: 16
- chips: 999 (pill)

---

# Component Rules

## Primary Button
- Background: primary
- Text: white
- Height: 52
- Radius: 16
- Elevation: subtle
- Press animation: scale 0.98

## Secondary Button
- Background: white
- Border: none (unless strictly needed)
- Text: primary

## Inputs (Filled style)
- Background: sageSoft
- Radius: 16
- No underline borders
- Focus state: subtle primary border or glow

## Cards
- Background: white
- Elevation: 1–3
- Radius: 16
- Fade-in on appear

## Settings List (Profile support section)
- Use ListTile rows
- Minimal separators
- No pill buttons
- Destructive action in error color

---

# Motion Guidelines

Use Flutter:
- AnimatedOpacity
- AnimatedScale
- PageRouteBuilder (fade transitions)
- NavigationBar with smooth selection animation

Timing:
- 150–250ms
Curve:
- Curves.easeInOut

Motion should feel invisible, not decorative.

---

# Screen Guidance (Current App Improvements)

## Location Screen
- Replace separate Search button with filled SearchBar.
- Confirm location must be solid primary and dominant.

## Profile Screen
- Replace outlined legal buttons with settings-style list.
- Add avatar.
- Remove unnecessary borders.

## Publish Screen
- Use filled inputs.
- Big photo card (4:3 aspect ratio).
- Publish button solid primary.

## Search Screen
- Use segmented control (pill).
- Cards with hierarchy.
- Add subtle fade when results load.

---

# Anti-Patterns

Do NOT:
- Stack multiple outline buttons
- Use grey background everywhere
- Mix many border radii
- Use harsh shadows
- Over-animate