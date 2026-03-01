# Search Screen — Top-tier Spec (Calm Marketplace / Sage)

## Goal
Make Search the primary action and make results the hero.
Filters are secondary and compact.

References:
- Apple HIG: if search is important, make it clearly visible/primary. :contentReference[oaicite:3]{index=3}
- Material 3: Search + SearchBar patterns. :contentReference[oaicite:4]{index=4}
- Material 3: Chips for compact filtering. :contentReference[oaicite:5]{index=5}

---

## Visual Hierarchy (Top → Bottom)

### 1) Sticky Search Header (always visible)
A “header surface” that stays at the top while results scroll.

Header layout:
- Background: sageSoft (#EEF1EA)
- Padding: 16 (horizontal), 12 (vertical)
- Radius: 0 (full width), but inner components are radius 16

Components:
1) SearchBar (dominant)
   - Filled style, radius 16
   - Height 52
   - Leading icon: search
   - Trailing icon: clear (when text not empty)
   - Hint: "Search by keyword"
   - Optional: voice / filter icon (future)

2) Context row (compact)
   - Left: location chip/button "📍 MK8 1EA"
   - Right: filter chips (radius / sort)
   - This row is secondary: small typography + less height

### 2) Results Area (hero)
- Background: white
- Results show as Cards
  - Card radius 16
  - Elevation subtle (1–3)
  - Layout: image (4:3) + title bold + subtitle muted (location · distance)
  - Tap target: full card
- Empty state (when no results):
  - Icon + short copy + secondary action to adjust radius/location

---

## Filters (compact + modern)
Use chips, not form fields.

Filter chips (examples):
- Radius: segmented chips [3 mi] [10 mi]
- Category (optional): [All] [Services] [Items]
- Sort (optional): [Nearest] [Newest]

Rules:
- Chips sit under SearchBar, not above.
- Avoid big "Radius" label. Chips are self-explanatory.

---

## Motion (polish)
All motion subtle, 150–250ms, easeInOut.

- Cards: fade in on first appearance (avoid re-animating on every rebuild/scroll).
- Buttons/Cards: slight press scale (0.98) on tap down.
- Tab switch (if Search is first tab): fade transition 200ms.

No bounce. No long animations.

---

## Spacing & Type
- Spacing grid: 8/16/24/32
- Titles: Inter SemiBold
- Body: Inter Regular
- Colors:
  - Title: #111827
  - Body: #374151
  - Muted: #6B7280
  - Primary: #2F6B3F

---

## Implementation Notes (Flutter)
Preferred structure:
- CustomScrollView
  - SliverAppBar (pinned) with flexibleSpace = header (SearchBar + chips)
  - SliverList for results

Avoid:
- A standalone "Search" title above the SearchBar.
- Big stacked outlined buttons.
- Grey background everywhere.

Definition of “Top-tier”:
- SearchBar is the focal point.
- Results feel editorial and touch-friendly.
- Filters feel lightweight (chips).
- Motion is invisible but present.