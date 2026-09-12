---
name: Terminal Vanguard
colors:
  surface: '#10141a'
  surface-dim: '#10141a'
  surface-bright: '#353940'
  surface-container-lowest: '#0a0e14'
  surface-container-low: '#181c22'
  surface-container: '#1c2026'
  surface-container-high: '#262a31'
  surface-container-highest: '#31353c'
  on-surface: '#dfe2eb'
  on-surface-variant: '#cbc3d7'
  inverse-surface: '#dfe2eb'
  inverse-on-surface: '#2d3137'
  outline: '#958ea0'
  outline-variant: '#494454'
  surface-tint: '#d0bcff'
  primary: '#d0bcff'
  on-primary: '#3c0091'
  primary-container: '#a078ff'
  on-primary-container: '#340080'
  inverse-primary: '#6d3bd7'
  secondary: '#7bd0ff'
  on-secondary: '#00354a'
  secondary-container: '#00a6e0'
  on-secondary-container: '#00374d'
  tertiary: '#ffb95f'
  on-tertiary: '#472a00'
  tertiary-container: '#ca8100'
  on-tertiary-container: '#3e2400'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#d0bcff'
  on-primary-fixed: '#23005c'
  on-primary-fixed-variant: '#5516be'
  secondary-fixed: '#c4e7ff'
  secondary-fixed-dim: '#7bd0ff'
  on-secondary-fixed: '#001e2c'
  on-secondary-fixed-variant: '#004c69'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#10141a'
  on-background: '#dfe2eb'
  surface-variant: '#31353c'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  code-lg:
    fontFamily: JetBrains Mono
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 22px
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system establishes an atmospheric, focused synthesis of high-end developer tooling and tactical RPG telemetry. It is crafted for competitive software engineers, algorithmic problem-solvers, and tech-native gamers who value visual rigor, low cognitive friction, and dense utility.

The aesthetic philosophy is **Minimal Cyber-Tactical**:
- **Utilitarian Elegance:** Stripped of gaudy arcade gamification, unnecessary skeuomorphic particle bursts, or distracting cartoon avatars. Visual metaphors draw strictly from modernized IDEs, code diff views, Linux terminal consoles, and minimalist HUDs.
- **Focused Competitiveness:** The emotional register is calm, intense, and precise. High-stakes dual coding battles feel tactical, readable under fast-paced constraints, and free of visual clutter.
- **Subtle Gamification:** Progression metrics—such as experience points (XP), health pools (HP), rank ratings, and stat modifiers—are presented with geometric precision, crisp borders, and disciplined micro-accents rather than whimsical decorations.

## Colors

The palette is engineered specifically for prolonged, low-eye-strain mobile viewing while sustaining critical contrast levels across coding buffers, battle telemetry, and hierarchy indicators.

### Surface System
- **Canvas Base (`#0A0D12`):** Underlying window foundation, status bar canvas, and root scaffold.
- **Surface Layer 1 (`#0D1117`):** Primary screen background canvas.
- **Surface Layer 2 (`#161B22`):** Grouped panels, list item backgrounds, and card bodies.
- **Surface Layer 3 (`#21262D`):** Elevated overlays, bottom sheet modules, and input text fields.
- **Subtle Surface Border (`#30363D`):** Universal 1px structural stroke applied to panels, cards, dividers, and containment frames.

### Functional Accents
- **Primary Indigo (`#8B5CF6`, hover/active `#7C3AED`, deep `#6D28D9`):** Represents player XP, interactive CTAs, terminal focus rings, and primary action affordances.
- **Tactical Blue (`#38BDF8`, deep `#0284C7`):** Secondary accent reserved for system metrics, mana/energy, syntax highlights, and active telemetry filters.
- **Reward Gold (`#F59E0B`, deep `#D97706`):** Reserved for star achievements, currency balances, streak modifiers, and gold tier rankings.
- **Combat Red (`#EF4444`, deep `#DC2626`):** Dedicated to enemy damage gauges, failed test suites, time pressure warnings, and critical compilation errors.
- **Combat Green (`#10B981`, deep `#059669`):** Dedicated to test suite pass states, ally HP pools, positive rating deltas, and compiler success confirmations.

## Typography

Typography establishes clear visual segregation between natural language UI narratives and runtime code execution states.

- **Inter (Interface Typography):** Drives all narrative instructions, modal dialogues, problem summaries, headers, and navigation states. Tightened letter spacing at headline levels preserves vertical density.
- **JetBrains Mono (Technical Telemetry):** Mandatory for code snippets, raw inputs, battle damage numbers, time clocks, Elo/MMR numbers, streak counts, and inventory metadata. Tabular numbers are default to avoid layout shift during fast combat countdowns and real-time test execution.
- **All Caps Usage:** Reserved strictly for `label-sm` and `label-md` when used in micro-badges, status pills (e.g., `PASS`, `FAIL`, `DIFF`, `LVL 42`), and stat categorizations.

## Layout & Spacing

Designed primarily for mobile screen dimensions (390x844 viewport standards), the layout operates on a strict **8px base grid system** (with 4px sub-increments for compact telemetry tags).

### Layout & Safe Areas
- **Screen Margins:** Fixed `16px` horizontal padding (`margin`) ensures content avoids screen edges while maximizing code line length.
- **Vertical Rhythm:** 
  - Standard spacing between stacked cards and section headers is `16px` (`space-md`).
  - Internal card padding defaults to `16px` (`space-md`), collapsing to `12px` for dense status indicators and battle action bars.
  - Micro-element spacing (icon-to-label, badge internal padding) utilizes `4px` (`space-xs`) or `8px` (`space-sm`).

### Layout Architecture (Flutter Equivalents)
- **Scaffold Base:** Dark canvas container holding fixed bottom navigation bar and scrolling `ListView` or `CustomScrollView`.
- **Battle HUD:** `Stack` with top-anchored opponent/player telemetry split via a two-column `Row`, center-docked scrollable code editor or battle arena, and bottom-anchored fixed command palette.
- **Cards & Containers:** Composed of nested `Row` and `Column` widgets using explicit cross-axis alignment to preserve monospaced data alignment.

## Elevation & Depth

Rather than relying on heavy, simulated directional lights or high-radius blurs, depth is communicated through **structural luminance layering** and **fine perimeter strokes**.

### Surface Stacking Tiers
1. **Tier 0 (Root Background):** `#0A0D12` / `#0D1117` — Receded base.
2. **Tier 1 (Resting Panel):** `#161B22` with a 1px border of `#30363D`. Zero ambient shadow.
3. **Tier 2 (Elevated Control / Active Card):** `#21262D` with a 1px border of `#30363D` and an ambient shadow: `0px 4px 12px rgba(0, 0, 0, 0.45)`.
4. **Tier 3 (Floating Overlays / Modals / Persistent Bottom Nav):** `#161B22` at 92% opacity with a `backdrop-filter: blur(12px)` and top border highlight (`#30363D`).

### Glow Accents & Combat States
- Interactive focus states and critical hits employ subtle, localized glow effects rather than drop shadows: `0px 0px 8px rgba(139, 92, 246, 0.35)` for primary indigo elements, and `0px 0px 8px rgba(239, 68, 68, 0.35)` for low-health/danger warnings.

## Shapes

The shape system employs a unified, compact corner curvature that sits between technical precision and tactile modern handheld comfort.

- **Primary Cards and Panels:** `12px` border radius (`rounded-lg`). Creates a structured, modular feel that echoes IDE split panes.
- **Input Fields, Terminal Blocks, and Code Canvases:** `8px` to `10px` border radius (`rounded`). Preserves rectangular discipline for monospaced content.
- **Buttons, Badges, and Micro Chips:** `8px` for compact controls; full pill radius (`9999px`) is used exclusively for numeric status pips, avatar rings, and mini XP counter tags.

## Components

### 1. Buttons
- **Primary CTA:** Background `#8B5CF6`, text `#FFFFFF` (`Inter` 14px Semibold), height `44px`, corner radius `10px`. Pressed state: `#7C3AED`. Active scale feedback: `0.98`.
- **Secondary Action:** Background `#21262D`, border `1px solid #30363D`, text `#C9D1D9`. Pressed state: `#30363D`.
- **Terminal / Quick Action:** Height `32px`, font `JetBrains Mono` 12px, border `1px solid #30363D`, background `#161B22`.

### 2. Persistent Bottom Navigation Bar
- Fixed `64px` height dock (excluding home indicator safe area), background `#161B22` at 94% opacity with background blur.
- Top boundary defined by a 1px border in `#30363D`.
- **5 Navigation Items:** `Home`, `Battle`, `Practice`, `Rank`, `Profile`.
- Active state: `#8B5CF6` icon and label with an optional 3px top indicator bar or soft glowing dot. Inactive state: `#8B949E` with no background container.

### 3. Cards & Panels
- Background `#161B22`, border `1px solid #30363D`, border radius `12px`, padding `16px`.
- Card Header: `Row` housing title in `Inter` 16px bold, accompanied by right-aligned stats in `JetBrains Mono` 12px.
- Internal separators: 1px horizontal rule in `#21262D`.

### 4. RPG Telemetry: Health, Energy & XP Gauges
- **Track:** 6px or 8px tall container, background `#21262D`, rounded `4px`.
- **Fill Segments:**
  - Ally / Current HP: Solid `#10B981` transitioning to `#EF4444` when under 25%.
  - Opponent HP: Solid `#EF4444`.
  - Player XP: Solid `#8B5CF6`.
- **Labels:** Accompanying text formatted in `JetBrains Mono` 11px uppercase (e.g., `HP 420/500`, `XP 84%`), aligned along the top or trailing edge of the bar.

### 5. Input Fields & Code Editor Viewports
- Text inputs use `#161B22` fill, 1px border `#30363D`, focus ring `1px solid #8B5CF6`.
- Inline code editor blocks utilize `#0D1117` base fill, left-anchored line number column styled in `JetBrains Mono` 12px muted gray (`#484F58`), with syntax highlighting mapped directly to system accents (keywords in `#8B5CF6`, constants in `#38BDF8`, errors in `#EF4444`).

### 6. Chips & Rank Badges
- **Rank Indicator:** Square or 8px-rounded badge, dark fill `#161B22`, border `1px solid #F59E0B` (for Gold) or `#8B5CF6` (for Master), displaying Roman numeral or numeric MMR in `JetBrains Mono`.
- **Status Chips:** Height `24px`, padding `2px 8px`, border radius `6px`, font `JetBrains Mono` 11px uppercase. Examples: `RUNNING` (Blue background tint `rgba(56, 189, 248, 0.1)`), `FAILED` (Red tint), `PASSED` (Green tint).

### 7. Form Controls (Checkboxes & Radios)
- Checkboxes: 18x18px squares with 4px border radius, border `1.5px solid #30363D`, active state filled with `#8B5CF6` and a crisp white geometric checkmark.
- Radio buttons: 18x18px circles with centered 6px dot upon selection.