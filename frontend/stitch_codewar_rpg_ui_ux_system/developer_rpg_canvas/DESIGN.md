---
name: Developer RPG Canvas
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
  on-surface-variant: '#c7c4d7'
  inverse-surface: '#dfe2eb'
  inverse-on-surface: '#2d3137'
  outline: '#908fa0'
  outline-variant: '#464554'
  surface-tint: '#c0c1ff'
  primary: '#c0c1ff'
  on-primary: '#1000a9'
  primary-container: '#8083ff'
  on-primary-container: '#0d0096'
  inverse-primary: '#494bd6'
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
  primary-fixed: '#e1e0ff'
  primary-fixed-dim: '#c0c1ff'
  on-primary-fixed: '#07006c'
  on-primary-fixed-variant: '#2f2ebe'
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
  headline-xl:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '600'
    lineHeight: 44px
  headline-xl-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  code-lg:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The product merges the focused utility of high-end software development environments with the intrinsic motivation of classic role-playing mechanics. The visual ratio is deliberate: 85% high-grade, utilitarian developer tooling and 15% quiet, understated gamification.

The aesthetic avoids the chaotic noise, heavy 3D assets, and neon glow of conventional gaming dashboards. Instead, it mirrors modern terminal workflows, minimalist IDE layouts, and contemporary code review surfaces. The RPG elements (character levels, experience points, quest completions, and streak counters) are integrated as low-friction telemetry rather than disruptive spectacle. Every interaction aims to induce flow state—quiet, deliberate, and free of visual friction.

## Colors

The palette is tuned specifically for sustained nighttime and deep-focus work:

- **Base Surfaces**: The deep background uses near-black slate `#0b0e14`, stepping up to `#0d1117` for base canvas and `#161b22` for standard panels and elevated code blocks.
- **Borders & Dividers**: Visual separation relies on delicate 1px borders using `#21262d` for interior structural rules and `#30363d` for interactive or card-level boundaries.
- **Primary & Interactive**: Muted indigo `#6366f1` and soft periwinkle `#818cf8` handle interactive actions, active navigation states, and primary focus rings.
- **Accent & RPG Telemetry**:
  - Sky Blue (`#38bdf8`): Subtly used for code metadata, branch references, and mana/focus indicators.
  - Amber/Gold (`#f59e0b`): Reserved strictly for currency, active solve streaks, and rare achievement milestones.
  - Emerald Green (`#22c55e`): Unit test passes, build success, and completed stages.
  - Coral Red (`#ef4444`): Test failures, syntax errors, and depleted vitality states.
- **Text & Foreground**: Full-contrast white is minimized. Primary text rests at `#e6edf3`, secondary text at `#8b949e`, and tertiary labels or comments at `#484f58`.

## Typography

The type scale maintains strict typographic separation between standard interface flow and runtime data:

- **Prose & Layout**: `Inter` is utilized for page headers, explanations, task descriptions, and navigation elements. Tracking is set to tight (`-0.01em` to `-0.02em`) on headings to maintain optical density.
- **Code, Telemetry & Status**: `JetBrains Mono` handles all monospaced requirements, code snippets, diffs, command-line outputs, stat counters (XP, Level, Streak, Rank), and data pills. Monospaced type must never be used for extended instructional paragraphs.
- **Tabular Data**: Numeric counters and timers must always leverage tabular numerals (`tnum`) to avoid layout jitter during active code runs or live combat ticks.

## Layout & Spacing

The interface uses a functional fluid grid with explicit content constraints to sustain code legibility:

- **Grid Framework**: 12-column dynamic grid on desktop views, transitioning to a single-column stacked layout on mobile viewports.
- **Section Rhythm**: Sections and major operational panes are spaced with a consistent `1.5rem` (24px) vertical cadence. Micro-spacing within component rows adheres to standard multiples of `0.25rem` (4px).
- **Surface Allocation**: The IDE and terminal panes hold spatial priority, claiming 60–70% of viewport width in duel/challenge views. The RPG telemetry (level, quest conditions, live battle state) sits in a dedicated, compact side panel spanning the remaining space.
- **Density Controls**: Data layouts rely on vertical edge alignments and border rules rather than heavy wrapping boxes, maximizing horizontal text scanning area.

## Elevation & Depth

Visual hierarchy is constructed through surface lightness, crisp hair-width borders, and restrained directional depth:

- **Surface Layering**:
  - `Level 0 (Canvas)`: `#0b0e14` — Base application background.
  - `Level 1 (Panels & Shells)`: `#0d1117` — Primary terminal, editor framing, and sidebar containers.
  - `Level 2 (Inspectors & Insets)`: `#161b22` — Code blocks, input containers, active list rows, and modal dialogs.
  - `Level 3 (Popovers & Tooltips)`: `#21262d` — Floating overlays and floating contextual menus.
- **Borders over Shadows**: Spatial definition is created primarily via `1px solid #21262d` or `1px solid #30363d` rather than heavy blur shadows.
- **Shadow Profile**: Elevated surfaces (modals, dropdowns) employ a single, highly diffused, dark tint: `0 10px 24px -4px rgba(0, 0, 0, 0.5), 0 2px 6px -1px rgba(0, 0, 0, 0.3)`.

## Shapes

The interface embraces a precise, calibrated roundness that balances modern software polish with technical utility:

- **Base Radius**: Standard interactive controls (buttons, input fields, dropdown toggles, and status badges) utilize an 8px radius (`roundedness: 2`).
- **Surface Containers**: Cards, code editors, and floating modals use a 10px radius (`rounded-lg`).
- **Telemetry Indicators**: Progress bars, health/XP bars, and mini avatar frames use full-pill styling (`rounded-full`) to immediately contrast against rigid code-block windows.

## Components

### Buttons
- **Primary**: Background `#6366f1`, text `#ffffff`, subtle inset top highlight `inset 0 1px 0 rgba(255, 255, 255, 0.15)`, radius 8px, padding `8px 16px`. Active press scales down to `0.98`.
- **Secondary / Ghost**: Background `transparent`, border `1px solid #30363d`, text `#e6edf3`, hover background `#161b22`.
- **Terminal Action**: Monospaced small button, background `#21262d`, border `1px solid #30363d`, text `#8b949e`, hover text `#e6edf3`.

### Badges & RPG Telemetry Chips
- **Level & Class Pill**: Low-profile badge. Background `#161b22`, border `1px solid #30363d`, text `JetBrains Mono 11px`, subtle accent dot (Indigo for Level, Amber for Streaks).
- **Progress Trackers**: Minimal horizontal bars (4px–6px height). Background track `#21262d`, fill color `#6366f1` (XP) or `#22c55e` (Health/Passing Tests). No particle sparks or glowing blooms.
- **Streak Counter**: `#f59e0b` text with an aligned monospaced counter (e.g., `12d_streak`), wrapped in `rgba(245, 158, 11, 0.1)` tint with a `1px solid rgba(245, 158, 11, 0.2)` outline.

### Lists vs. Cards
- **Challenge Lists**: Avoid bulky isolated cards. Use full-width structured list rows separated by `1px solid #21262d`. Hover state transitions background to `#161b22` smoothly (`120ms ease`).
- **Row Anatomy**: Left side displays challenge name and tags (`Inter 14px`); right side displays completion status, reward value (`JetBrains Mono 12px`), and action affordance.

### Input Fields & Terminal Console
- **Inputs**: Background `#0d1117`, border `1px solid #30363d`, radius 8px, font `Inter 14px`, text `#e6edf3`. On focus: border `#6366f1` with zero fuzzy glow—clean single outline.
- **Terminal Console**: Background `#0b0e14`, border `1px solid #21262d`, font `JetBrains Mono 13px`, prompt identifier colored in `#38bdf8`.

### Checkboxes & Radios
- Square 16px with 4px border radius for checkboxes. Border `1px solid #30363d`, background `#161b22`. Checked state: background `#6366f1` with a clean 1.5px white checkmark icon.