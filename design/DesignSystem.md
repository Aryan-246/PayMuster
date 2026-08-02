# PayMuster Design System

**Status**: Design foundation complete — implementation pending approval  
**Version**: 1.1.0  
**Last Updated**: 2026-07-29

---

## Overview

The PayMuster Design System is a comprehensive specification for building a premium Workforce Operating System UI across web and mobile platforms. Every component, token, and interaction flows from this single source of truth.

**Design Philosophy**: Industrial · Premium · Minimal · Dark · High Contrast · Glove-Friendly

---

## 1. Color System

### Brand Colors (Derived from PayMuster Logo)

The PayMuster logo uses a vibrant teal/cyan color. All brand tokens are derived from this mark:

```
Logo Primary: #15D1C2 (Teal-Cyan)
Logo Secondary: #0E7C86 (Deep Teal)
```

### Semantic Color Palette

#### Primary Actions
- **Brand Teal**: `#15D1C2` (Primary CTA buttons, active states, brand accent)
- **Brand Teal Dark**: `#0E7C86` (Hover, secondary brand accents)

#### Status Colors
- **Success**: `#10B981` (Green) — Present, Approved, Delivered
- **Warning**: `#FDBA2D` (Amber/Gold) — Half Day, Pending, Overtime
- **Danger**: `#EF4444` (Red) — Absent, Rejected, Error
- **Info**: `#3B82F6` (Blue) — Information, Secondary action, Leave

#### Neutral Background
- **Dark Background**: `#0B1117` (Primary app background, darkest)
- **Dark Surface**: `#161B22` (Secondary surfaces, cards, modals)
- **Dark Secondary**: `#1D2530` (Tertiary surfaces, disabled states)

#### Neutrals & Text
- **Text Primary**: `#FFFFFF` (Headings, labels, primary text)
- **Text Secondary**: `#8B95A5` (Body text, descriptions, captions)
- **Text Tertiary**: `#6B7280` (Disabled text, hints)
- **Border**: `rgba(255,255,255,0.12)` (Dividers, subtle borders)
- **Border Subtle**: `rgba(255,255,255,0.06)` (Very subtle borders)

### Color Reference

```css
/* Semantic Tokens */
--color-primary: #15D1C2;
--color-primary-dark: #0E7C86;
--color-success: #10B981;
--color-warning: #FDBA2D;
--color-danger: #EF4444;
--color-info: #3B82F6;

/* Backgrounds */
toggal and many more effect
/* Text */
--text-primary: #FFFFFF;
--text-secondary: #8B95A5;
--text-tertiary: #6B7280;

/* Borders */
--border: rgba(255,255,255,0.12);
--border-subtle: rgba(255,255,255,0.06);
```

---

## 2. Typography

### Font Stack

```css
font-family: 'Inter', 'Segoe UI', system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
```

**Rationale**: Inter is used by Stripe, Linear, and Vercel. It's modern, highly legible, and optimized for screens.

### Type Scale

| Usage | Weight | Size (Mobile) | Size (Web) | Line Height | Letter Spacing |
|---|---|---|---|---|---|
| **Display** (Hero titles) | 700 | 32px | 40px | 1.2 | -0.02em |
| **Heading 1** | 700 | 28px | 32px | 1.2 | -0.01em |
| **Heading 2** | 600 | 24px | 28px | 1.2 | 0 |
| **Heading 3** | 600 | 20px | 24px | 1.3 | 0 |
| **Subtitle** | 500 | 16px | 18px | 1.4 | 0 |
| **Body** | 400 | 14px | 15px | 1.5 | 0 |
| **Caption** | 500 | 12px | 12px | 1.4 | 0.01em |
| **Small** | 400 | 12px | 12px | 1.5 | 0 |
| **Tiny** | 400 | 11px | 11px | 1.4 | 0.02em |

### Usage Guidelines

- **Display**: Page hero sections, splash screens
- **Heading 1**: Page titles, modal titles
- **Heading 2**: Section titles, card headers
- **Heading 3**: Subsection titles, list group headers
- **Subtitle**: Secondary headings, metadata labels
- **Body**: Main content text, descriptions, table cells
- **Caption**: Secondary labels, timestamps, breadcrumbs
- **Small**: Helper text, error messages, tool tips
- **Tiny**: Tags, badges, small UI labels

### Minimum Size Rule
- **Mobile**: Minimum 14px for any interactive text
- **Web**: Minimum 12px only for captions/helpers; body text never below 14px

---

## 3. Spacing System

All spacing follows an **8px base grid**. This creates a predictable, rhythm-driven layout system.

```css
/* Spacing Scale */
--space-0: 0px;
--space-1: 4px;   /* xs: tight gaps between related elements */
--space-2: 8px;   /* sm: padding in compact components */
--space-3: 12px;  /* compact spacing between components */
--space-4: 16px;  /* md: standard padding, section gaps */
--space-5: 20px;  /* semi-large spacing */
--space-6: 24px;  /* lg: section separation */
--space-7: 32px;  /* xl: major section gaps */
--space-8: 40px;  /* 2xl: page-level gaps */
--space-9: 48px;  /* 3xl: full-page padding */
--space-10: 64px; /* 4xl: hero sections */
```

### Application

| Area | Spacing | Notes |
|---|---|---|
| **Component Padding** | 16px (md) | Cards, buttons, input fields |
| **Component Gap** | 8px (sm) | Space between icon and text |
| **Section Separation** | 24px (lg) | Between major content blocks |
| **Page Padding (Mobile)** | 16px (md) | All edges |
| **Page Padding (Web)** | 24px–32px | Larger screens, sidebar-aware |
| **List Item Gap** | 8px–12px | Vertical space between rows |

---

## 4. Border Radius

Consistent radius scale for depth and visual hierarchy:

```css
--radius-0: 0px;     /* no radius (rare) */
--radius-1: 4px;     /* subtle, tight components */
--radius-2: 6px;     /* small cards, inputs */
--radius-3: 8px;     /* standard buttons, small cards */
--radius-4: 12px;    /* cards, modals (most common) */
--radius-5: 16px;    /* large panels, hero cards */
--radius-6: 20px;    /* very large surfaces */
--radius-max: 99px;  /* pills, badges, circles */
```

### Component Mapping

| Component | Radius |
|---|---|
| **Button** | 8px (--radius-3) |
| **Input Field** | 8px (--radius-3) |
| **Small Card** | 8px (--radius-3) |
| **Standard Card** | 12px (--radius-4) |
| **Modal/Dialog** | 16px (--radius-5) |
| **Sidebar** | 12–16px (--radius-4 to --radius-5) |
| **Large Panel** | 16px–20px (--radius-5 to --radius-6) |
| **Badge/Tag** | 99px (--radius-max, pill shape) |
| **Avatar** | 99px (--radius-max, circular) |

---

## 5. Elevation & Shadows

Subtle shadows create depth without overwhelming. Never use heavy/drop shadows.

```css
/* Shadow Scale */
--shadow-none: 0;

--shadow-1: 0 1px 2px rgba(0, 0, 0, 0.2);
--shadow-2: 0 2px 4px rgba(0, 0, 0, 0.24);
--shadow-3: 0 4px 8px rgba(0, 0, 0, 0.28);
--shadow-4: 0 8px 16px rgba(0, 0, 0, 0.32);
--shadow-5: 0 16px 32px rgba(0, 0, 0, 0.36);
--shadow-6: 0 24px 48px rgba(0, 0, 0, 0.4);

/* Elevation Variants */
--elevation-flat: 0;
--elevation-1: 0 1px 2px rgba(0, 0, 0, 0.2);
--elevation-2: 0 2px 4px rgba(0, 0, 0, 0.24);
--elevation-raised: 0 4px 12px rgba(0, 0, 0, 0.28);
--elevation-floating: 0 8px 24px rgba(0, 0, 0, 0.32);
--elevation-modal: 0 16px 48px rgba(0, 0, 0, 0.4);
```

### Application

| Component | Elevation |
|---|---|
| **Flat background** | --elevation-flat (none) |
| **Input, Disabled** | --elevation-flat |
| **Standard Card** | --shadow-1 |
| **Hover Card** | --shadow-2 |
| **Interactive Card (hover)** | --shadow-3 |
| **Floating Panel** | --shadow-4 |
| **Dropdown, Context Menu** | --shadow-4 |
| **Modal Overlay** | --shadow-5 |
| **Floating Action Button** | --shadow-4 |
| **Tooltip** | --shadow-3 |

---

## 6. Icon System

### Icon Library
- **Primary**: Lucide Icons (consistent, modern, open-source)
- **Fallback**: Material Symbols
- **Custom**: SVG for PayMuster-specific icons (e.g., logo mark)

### Icon Sizes

```css
--icon-xs: 12px;
--icon-sm: 16px;
--icon-md: 20px;
--icon-lg: 24px;
--icon-xl: 32px;
--icon-2xl: 48px;
--icon-3xl: 64px;
```

### Icon Usage Guidelines

| Context | Size | Color |
|---|---|---|
| **Navigation (Sidebar/Tab)** | 20px–24px | --text-secondary (inactive), --color-primary (active) |
| **Button Icon** | 16px–20px | Inherit button text color |
| **Input Field Icon** | 16px | --text-secondary |
| **Card Icon** | 24px | --color-primary or --text-secondary |
| **Status Indicator** | 16px | Status color (success/warning/danger/info) |
| **Card Accent** | 32px–48px | --color-primary at 10–20% opacity |

---

## 7. Component Specifications

### 7.1 Buttons

#### Primary Button
```
Background: --color-primary (#15D1C2)
Text: #0B1117 (dark text for contrast)
Border: none
Padding: 12px 20px (mobile), 12px 24px (web)
Height: 48px (mobile), 40px (web)
Radius: --radius-3 (8px)
Shadow: 0 4px 12px rgba(21, 209, 194, 0.25) [brand shadow]
Hover: 
  - Brightness: +10%
  - Shadow: 0 6px 16px rgba(21, 209, 194, 0.35)
  - Transform: translateY(-1px) [subtle lift]
Active:
  - Brightness: -5%
  - Transform: none
Disabled:
  - Opacity: 50%
  - Cursor: not-allowed
```

#### Secondary Button
```
Background: transparent
Border: 1px solid --border (#rgba(255,255,255,0.12))
Text: --text-primary (#FFFFFF)
Padding: 12px 20px
Height: 48px (mobile), 40px (web)
Radius: --radius-3 (8px)
Hover:
  - Background: rgba(255,255,255,0.08)
  - Border: 1px solid --color-primary
Active:
  - Background: rgba(255,255,255,0.12)
Disabled:
  - Opacity: 50%
```

#### Tertiary Button (Ghost)
```
Background: transparent
Border: none
Text: --text-secondary
Padding: 8px 12px (compact)
Hover:
  - Background: rgba(255,255,255,0.06)
  - Text: --text-primary
Active:
  - Background: rgba(255,255,255,0.12)
```

#### Danger Button
```
Background: --color-danger (#EF4444)
Text: #FFFFFF
Padding: 12px 20px
Height: 48px
Radius: --radius-3 (8px)
Always requires confirmation dialog
Hover: Brightness +5%
```

### 7.2 Input Fields

```
Background: --bg-tertiary (#1D2530)
Border: 1px solid --border
Padding: 12px 16px
Height: 48px (mobile), 40px (web)
Radius: --radius-3 (8px)
Font: Body (14px)
Placeholder: --text-tertiary
Focus:
  - Border: 1px solid --color-primary
  - Shadow: 0 0 0 3px rgba(21, 209, 194, 0.1)
Disabled:
  - Background: --bg-secondary
  - Text: --text-tertiary
  - Cursor: not-allowed
Error:
  - Border: 1px solid --color-danger
  - Shadow: 0 0 0 3px rgba(239, 68, 68, 0.1)
```

### 7.3 Cards

```
Background: --bg-secondary (#161B22)
Border: 1px solid --border
Padding: 16px (mobile), 20px (web)
Radius: --radius-4 (12px)
Shadow: --shadow-1
Hover (if interactive):
  - Shadow: --shadow-2
  - Transform: translateY(-2px)
```

### 7.4 Tables

```
Header Row:
  Background: --bg-tertiary
  Text: --text-secondary, Medium weight (500)
  Padding: 12px 16px
  Font Size: 12px
  Border Bottom: 1px solid --border
  Sticky: yes, on scroll

Body Row:
  Background: --bg-secondary
  Text: --text-primary
  Padding: 12px 16px
  Min Height: 48px
  Border Bottom: 1px solid --border-subtle
  Hover:
    Background: rgba(255,255,255,0.04)

Alternating Rows: Not needed (borders provide contrast)
```

### 7.5 Modals & Dialogs

```
Overlay:
  Background: rgba(0, 0, 0, 0.6)
  Backdrop Filter: blur(4px)

Modal:
  Background: --bg-secondary
  Border: 1px solid --border
  Radius: --radius-5 (16px)
  Shadow: --shadow-5 (modal depth)
  Padding: 24px (web), 20px (mobile)
  Max Width: 600px (md), 800px (lg)
  
Header:
  Font: Heading 2
  Margin Bottom: 16px
  
Footer:
  Margin Top: 24px
  Display: flex, gap 8px
  Button Layout: secondary first (left), primary second (right)

Close Button:
  Position: top right
  Icon: X (16px)
  Radius: --radius-3
```

### 7.6 Bottom Sheets (Mobile)

```
Overlay: rgba(0, 0, 0, 0.4)

Sheet:
  Background: --bg-secondary
  Radius: --radius-5 (16px) top only
  Position: bottom, full width
  Max Height: 90vh
  Padding: 20px
  
Header (with drag handle):
  Drag Handle: 4px × 40px bar, centered, --text-tertiary
  Margin Bottom: 12px

Animation:
  Slide up from bottom: 300ms ease-out
  Slide down on close: 200ms ease-in
```

### 7.7 Toast/Snackbar

```
Position: Bottom center (mobile), Bottom right (web)
Width: 90vw (mobile), 380px (web)
Padding: 16px
Radius: --radius-4 (12px)
Shadow: --shadow-4
Duration: 3–4 seconds (auto-dismiss)
Gap from viewport edge: 16px

Success Toast:
  Background: rgba(16, 185, 129, 0.1)
  Border: 1px solid --color-success
  Text: --color-success

Error Toast:
  Background: rgba(239, 68, 68, 0.1)
  Border: 1px solid --color-danger
  Text: --color-danger

Info Toast:
  Background: rgba(59, 130, 246, 0.1)
  Border: 1px solid --color-info
  Text: --color-info

Warning Toast:
  Background: rgba(253, 186, 45, 0.1)
  Border: 1px solid --color-warning
  Text: --color-warning
```

### 7.8 Badges & Tags

```
Background: --color-primary at 15% opacity
Text: --color-primary
Padding: 4px 12px
Radius: --radius-max (pill)
Font: Caption (12px), Medium weight (500)
Border: 1px solid --color-primary at 30% opacity

Variants:
  Success Badge:
    Background: --color-success at 15%
    Text: --color-success
    Border: --color-success at 30%
    
  Danger Badge:
    Background: --color-danger at 15%
    Text: --color-danger
    Border: --color-danger at 30%
```

### 7.9 Skeleton Loading

```
Base Color: --bg-tertiary
Animation: Shimmer (left-to-right sweep, 1.5s ease-in-out, infinite)
Shimmer Color: rgba(255, 255, 255, 0.08)
Radius: Match target component (8px for cards, 12px for larger)

Line Skeleton:
  Height: 16px
  Radius: 4px
  Margin Bottom: 8px

Card Skeleton:
  Height: 200px
  Radius: 12px
  Padding: 16px

Avatar Skeleton:
  Width: 48px
  Height: 48px
  Radius: 99px (circular)
```

### 7.10 Empty States

```
Container:
  Padding: 48px (web), 32px (mobile)
  Text Align: center
  
Icon:
  Size: 64px
  Color: --color-primary at 30% opacity
  Margin Bottom: 16px
  
Title:
  Font: Heading 2 (24px)
  Color: --text-primary
  Margin Bottom: 8px
  
Description:
  Font: Body (14px)
  Color: --text-secondary
  Margin Bottom: 24px
  Max Width: 400px
  
CTA Button:
  Type: Primary
  Margin Bottom: 0
```

### 7.11 Error States

```
Error Container:
  Background: rgba(239, 68, 68, 0.1)
  Border: 1px solid --color-danger
  Radius: --radius-4 (12px)
  Padding: 16px
  
Icon:
  Size: 20px
  Color: --color-danger
  Margin Right: 12px (inline)
  
Title:
  Font: Subtitle (16px)
  Color: --color-danger
  Margin Bottom: 4px
  
Message:
  Font: Body (14px)
  Color: --text-secondary
  
Retry Button:
  Type: Secondary (or Primary if critical)
  Size: sm (compact)
  Margin Top: 12px
```

### 7.12 Timeline Component

```
Container:
  Padding: 0
  
Timeline Item:
  Display: flex
  Margin Bottom: 16px
  
Dot:
  Width: 12px
  Height: 12px
  Radius: 99px
  Margin Right: 16px
  Flex Shrink: 0
  
Content:
  Flex: 1
  
Time (Caption):
  Font: Caption (12px)
  Color: --text-tertiary
  Margin Bottom: 2px
  
Title (Subtitle):
  Font: Subtitle (16px)
  Color: --text-primary
  Margin Bottom: 4px
  
Description:
  Font: Body (14px)
  Color: --text-secondary
  
Connector Line:
  Vertical line from dot to next item
  Width: 2px
  Color: --border
```

### 7.13 AI Components

#### AI Message Bubble
```
User Message:
  Background: --color-primary at 20%
  Text: --text-primary
  Alignment: Right
  Radius: --radius-4 (12px)
  Padding: 12px 16px
  Max Width: 70% (web), 85% (mobile)

AI Message:
  Background: --bg-secondary
  Border: 1px solid --color-primary at 30%
  Text: --text-primary
  Alignment: Left
  Radius: --radius-4
  Padding: 12px 16px
  Max Width: 70% (web), 85% (mobile)
  Icon: AI mark (16px) before text

AI Input:
  Similar to standard input
  Icon: Microphone (voice input)
  Placeholder: "Ask me anything..."
```

#### AI Suggestion Card
```
Background: rgba(21, 209, 194, 0.1)
Border: 1px solid --color-primary at 30%
Radius: --radius-4
Padding: 12px 16px
Icon: Sparkle (16px), --color-primary
Text: --text-secondary (14px)
Hover: Background opacity +5%
```

---

## 8. Loading States

### Shimmer Effect
```
Duration: 1.5s
Easing: ease-in-out
Direction: Left to right
Sweep Width: 100px
Color: rgba(255, 255, 255, 0.08)
Repeat: Infinite
```

### Skeleton Patterns

#### List Item Skeleton
```
Avatar (circular): 40px
Title line: 24px height
Subtitle line: 16px height (60% width)
Spacing: 8px between lines
```

#### Card Skeleton
```
Header bar: 200px height
Content lines: 3× 16px lines
Spacing: 12px between
```

---

## 9. Navigation Patterns

### Mobile Bottom Navigation
```
Background: --bg-secondary
Height: 60px (safe area aware)
Border Top: 1px solid --border

Tab Item:
  Flex: 1
  Display: flex (column, centered)
  Icon: 24px
  Label: 12px Caption weight 500
  Color (inactive): --text-secondary
  Color (active): --color-primary
  Spacing: 4px between icon and label
```

### Desktop Sidebar
```
Width: 280px (expanded), 80px (collapsed)
Background: --bg-secondary
Padding: 16px (expanded), 12px (collapsed)

Logo:
  Height: 40px
  Margin Bottom: 24px

Nav Item (expanded):
  Padding: 12px 16px
  Radius: --radius-3
  Gap (icon + text): 12px
  
  Hover: Background --bg-tertiary
  Active: 
    Background: --bg-tertiary
    Border Left: 3px solid --color-primary
    
Nav Item (collapsed):
  Padding: 12px
  Icon only
  Centered

Collapse Toggle:
  Position: bottom of sidebar
  Smooth animation (200ms)
```

---

## 10. Themes

### Dark Theme (Default)
```
Primary BG: #0B1117
Secondary BG: #161B22
Tertiary BG: #1D2530
Text Primary: #FFFFFF
Text Secondary: #8B95A5
Text Tertiary: #6B7280
Border: rgba(255,255,255,0.12)
Brand: #15D1C2
```

### Light Theme
```
Primary BG: #FFFFFF
Secondary BG: #F9FAFB
Tertiary BG: #F3F4F6
Text Primary: #1F2937
Text Secondary: #6B7280
Text Tertiary: #9CA3AF
Border: rgba(0,0,0,0.08)
Brand: #0E7C86
```

### AMOLED Theme (Pure Black)
```
Primary BG: #000000
Secondary BG: #0A0A0A
Tertiary BG: #1A1A1A
Text Primary: #FFFFFF
Text Secondary: #A0A0A0
Text Tertiary: #606060
Border: rgba(255,255,255,0.1)
Brand: #15D1C2 (same)
```

### System Theme
Auto-detect from device: Light / Dark / AMOLED

---

## 11. Animations & Transitions

### Timing Functions
```
Fast: 150ms ease-out
Standard: 200ms ease-out
Slow: 300ms ease-out
Spring: cubic-bezier(0.34, 1.56, 0.64, 1) [bounce-light]
```

### Common Transitions
```
Modal open: Scale + fade (200ms ease-out)
Modal close: Scale + fade (150ms ease-in)
Page transition: Fade (200ms ease-out)
Button hover: Brightness + shadow (150ms ease-out)
Sidebar collapse: Width (200ms ease-out)
Dropdown open: Scale + fade (150ms ease-out)
```

### Micro-interactions
```
Checkbox fill: 150ms ease-out
Toggle switch: 200ms ease-out
Counter increment: 300ms ease-out
Ripple effect: 300ms ease-out
FAB press: 100ms scale + feedback
```

---

## 12. Responsive Breakpoints

```css
--bp-mobile: 320px
--bp-tablet: 768px
--bp-desktop: 1024px
--bp-wide: 1440px
```

| Breakpoint | Layout |
|---|---|
| **Mobile** (< 768px) | Single column, bottom nav, full-width cards |
| **Tablet** (768–1024px) | Collapsible sidebar, 2-column grid |
| **Desktop** (≥ 1024px) | Fixed sidebar, multi-column layout |
| **Wide** (≥ 1440px) | Full sidebar, expanded cards, premium spacing |

---

## 13. Accessibility Standards

- **Contrast**: WCAG AAA (4.5:1 body, 3:1 large)
- **Touch Targets**: Minimum 48×48px
- **Focus Indicators**: 2px outline, --color-primary
- **ARIA Labels**: All icons, form inputs
- **Reduced Motion**: Disable animations if `prefers-reduced-motion` set
- **Keyboard Navigation**: Tab order logical, no traps
- **Screen Reader**: Semantic HTML, role attributes where needed

---

## 14. Design Tokens Reference

### Complete Token Map

```css
/* Colors */
--color-primary: #15D1C2;
--color-primary-dark: #0E7C86;
--color-success: #10B981;
--color-warning: #FDBA2D;
--color-danger: #EF4444;
--color-info: #3B82F6;

/* Backgrounds */
--bg-primary: #0B1117;
--bg-secondary: #161B22;
--bg-tertiary: #1D2530;

/* Text */
--text-primary: #FFFFFF;
--text-secondary: #8B95A5;
--text-tertiary: #6B7280;

/* Borders */
--border: rgba(255,255,255,0.12);
--border-subtle: rgba(255,255,255,0.06);

/* Spacing */
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 20px;
--space-6: 24px;
--space-7: 32px;
--space-8: 40px;
--space-9: 48px;

/* Radius */
--radius-1: 4px;
--radius-2: 6px;
--radius-3: 8px;
--radius-4: 12px;
--radius-5: 16px;
--radius-6: 20px;
--radius-max: 99px;

/* Shadows */
--shadow-1: 0 1px 2px rgba(0,0,0,0.2);
--shadow-2: 0 2px 4px rgba(0,0,0,0.24);
--shadow-3: 0 4px 8px rgba(0,0,0,0.28);
--shadow-4: 0 8px 16px rgba(0,0,0,0.32);
--shadow-5: 0 16px 32px rgba(0,0,0,0.36);

/* Typography */
--font-family: 'Inter', system-ui, sans-serif;
--font-size-xs: 11px;
--font-size-sm: 12px;
--font-size-base: 14px;
--font-size-md: 16px;
--font-size-lg: 20px;
--font-size-xl: 24px;
--font-size-2xl: 28px;
--font-size-3xl: 32px;
--font-size-4xl: 40px;

--font-weight-light: 300;
--font-weight-normal: 400;
--font-weight-medium: 500;
--font-weight-semibold: 600;
--font-weight-bold: 700;

/* Transitions */
--transition-fast: 150ms ease-out;
--transition-base: 200ms ease-out;
--transition-slow: 300ms ease-out;
```

---

## 15. Information Architecture

PayMuster is an operating system, not a collection of dashboards. Navigation must reflect the user's operational flow: understand the business, act on site, resolve exceptions, then review the record. Primary navigation contains durable workspaces; record details, creation flows, and utilities are reached through contextual actions, search, or the Command Center.

### 15.1 Desktop Navigation Tree

```
PayMuster
├── Home
│   ├── Dashboard
│   ├── Command Center
│   ├── Global Search
│   ├── Notifications
│   └── Activity Timeline
├── Workforce
│   ├── Workers
│   │   ├── Worker Profile
│   │   ├── Worker Ledger
│   │   ├── Attendance History
│   │   ├── Payment History
│   │   ├── Site History
│   │   ├── Asset History
│   │   └── Documents
│   ├── Attendance
│   │   ├── Daily Attendance
│   │   ├── Attendance Details
│   │   ├── Corrections
│   │   └── Attendance Conflicts
│   └── Sites
│       ├── Site Directory
│       ├── Site Details
│       ├── Assignments
│       ├── Site Progress Proofs
│       └── Site Cost Summary
├── Finance
│   ├── Payroll
│   │   ├── Pay Cycles
│   │   ├── Payroll Details / Pay Run
│   │   ├── Pay Slips
│   │   ├── Salary Rules
│   │   └── Full & Final Settlement
│   ├── Payments
│   │   ├── Payment Register
│   │   ├── Payment Details
│   │   ├── Batch Payments
│   │   ├── Advances
│   │   └── Payment Audit Trail
│   ├── Expenses
│   │   ├── Expense Register
│   │   ├── Expense Details
│   │   ├── Reimbursements
│   │   └── Receipt Review
│   └── Approvals
├── Operations
│   ├── Assets
│   │   ├── Asset Register
│   │   ├── Asset Details
│   │   ├── Issue / Return
│   │   ├── Transfers
│   │   └── Damage & Loss Review
│   ├── Materials
│   │   ├── Material Catalog
│   │   ├── Site Stock
│   │   ├── Material Transaction
│   │   ├── Delivery Proof
│   │   └── Low-stock Alerts
│   ├── Clients
│   │   ├── Client Directory
│   │   └── Client Details / Linked Sites
│   └── Vendors
│       ├── Vendor Directory
│       └── Vendor Details / Payment History
├── Intelligence
│   ├── Reports
│   │   ├── Attendance Report
│   │   ├── Payroll Report
│   │   ├── Payment Report
│   │   ├── Expense Report
│   │   ├── Asset Report
│   │   ├── Material Report
│   │   ├── Site Cost Report
│   │   ├── Worker Ledger Report
│   │   └── Compliance Report
│   └── AI Assistant
│       ├── Conversation
│       ├── Suggestions
│       ├── Anomalies
│       └── AI Settings
└── Organization
    ├── Profile
    ├── Settings
    │   ├── Organization
    │   ├── Users & Roles
    │   ├── Attendance & Payroll Rules
    │   ├── Payment & Expense Rules
    │   ├── Notification Preferences
    │   ├── Language & Appearance
    │   ├── Integrations
    │   └── Billing (Owner only)
    ├── Audit Log
    └── Help & Support
```

Desktop sidebar group labels are visible only when expanded. `Dashboard`, `Workers`, `Attendance`, `Sites`, `Payroll`, `Expenses`, `Reports`, and `Approvals` are the default high-frequency entries; role rules determine which of them appear. Payments, operational inventory, and business relationship modules remain discoverable in grouped navigation, never hidden behind an arbitrary “more” menu.

### 15.2 Mobile Navigation Tree

Mobile prioritizes the field loop and gives every role a compact, role-aware set of five tabs:

```
Dashboard | Workers | Attendance | Payroll* | More
```

`Payroll` is replaced by `Sites` for Supervisors and by `My Work` for Workers. `More` opens a full-height, searchable workspace list containing only pages the user can access. It contains Sites, Approvals, Expenses, Assets, Materials, Clients, Vendors, Reports, Notifications, Profile, Settings when permitted, Help, and sign out.

Mobile record views use a top app bar with Back, contextual title, sync state, and overflow actions. Deep links always resolve to a specific detail page, never merely the list page. Creation flows use a full screen when they require more than two fields, and a bottom sheet for focused, reversible choices.

### 15.3 AI Shortcuts

- The floating AI action is available on every authenticated screen except credential entry, destructive confirmation, camera capture, payment confirmation, and conflict resolution.
- The assistant opens with the current route, selected site, date range, and visible filters as read-only context. It must state this context before presenting a query result or suggestion.
- Contextual shortcuts appear as concise prompts: “Explain this payroll variance,” “Find missing attendance,” “Summarize Site Alpha,” and “Categorize this expense.”
- AI may navigate to a filtered view or prepare a draft, but any mutation requires an explicit review screen and the user’s confirmation. It never approves, pays, submits, deletes, or resolves a conflict.
- `Ctrl/Cmd + K` opens the Command Center; `/` focuses global search; both offer “Ask PayMuster” as a clearly labeled read-only AI action.

### 15.4 Future Modules and Navigation Contract

Future modules include Leave & Shift Planning, Purchase Orders, Invoicing, Compliance, Equipment Maintenance, Project Scheduling, Safety, Quality Inspections, Document Control, Workforce Skills, Integrations, and Multi-organization Administration. They do not appear in the default navigation until their scope, permissions, offline behavior, and reporting obligations are designed.

Every future module is registered in one of the existing workspaces or a new explicitly named workspace. It must provide: a list screen, a detail screen, a creation/edit path, empty/loading/error states, search metadata, audit events, permission declarations, notification/deep-link support where appropriate, and a mobile navigation strategy. No module may add an ungrouped sidebar icon or replace a primary tab without a navigation review.

---

## 16. Screen Inventory

This inventory is the canonical set of named screens for the planned product. A screen may have responsive layouts, but web and mobile must represent the same underlying task and state. Temporary loading, empty, offline, permission-denied, and error variants are required for each applicable data screen; they are not separate product routes.

### 16.1 Public, Authentication, and Onboarding

| Screen | Purpose | Primary Platforms |
|---|---|---|
| Splash | Restores session, initializes local data, and reports sync readiness | Mobile |
| Welcome / Onboarding | Explains proof-backed attendance and offline use | Mobile, Web |
| Language Selection | Sets initial language before sign-in; remains editable later | Mobile, Web |
| Sign In | Phone/email and password entry | Mobile, Web |
| OTP Verification | Verifies password reset, sign-in, or invitation where configured | Mobile, Web |
| Forgot Password | Starts password-reset OTP flow | Mobile, Web |
| Reset Password | Completes password reset after OTP verification | Mobile, Web |
| Accept Invitation | Accepts organization invitation and confirms role | Mobile, Web |
| Create Organization | Creates owner account and organization | Web, Mobile |
| Organization Setup | Captures business profile, currency, dates, and logo | Web, Mobile |
| First Site Setup | Creates the first site and geofence | Web, Mobile |
| First Worker Setup | Adds or imports the first worker | Web, Mobile |
| Setup Complete | Confirms readiness and directs to first workflow | Mobile, Web |

### 16.2 Home, Search, and System Screens

| Screen | Purpose |
|---|---|
| Dashboard | Role-specific operational summary and quick actions |
| Command Center | Keyboard-first command palette and fast actions |
| Global Search | Searches workers, sites, records, reports, and commands |
| Notifications | Read/unread notification center with deep links |
| Activity Timeline | Chronological, filterable organization activity and audit-adjacent events |
| Approvals | Unified queue for payments, expenses, advances, corrections, and damage reviews |
| AI Assistant | Read-only analysis, questions, suggestions, and human-confirmed draft actions |
| Offline Queue | Displays pending records, uploads, failures, and sync controls |
| Conflict Resolution | Compares conflicting offline records and records an authorized human decision |
| Permission Denied | Explains unavailable access without exposing protected data |
| Not Found | Provides recovery to the correct workspace |
| Maintenance / Forced Update | Safely blocks an incompatible client when required |

### 16.3 Workforce and Site Screens

| Screen | Purpose |
|---|---|
| Workers | Searchable, filterable worker directory |
| Add Worker | Creates worker identity, employment, and payment profile |
| Worker Profile | Overview of worker status, rate, assignments, and balance |
| Worker Edit | Edits permitted worker fields with audit-aware save behavior |
| Worker Documents | Uploads and reviews secure worker documents |
| Worker Attendance History | Shows proof-backed attendance history |
| Worker Payment History | Shows payment history and correction requests |
| Worker Site History | Shows site-assignment timeline |
| Worker Asset History | Shows issued, returned, damaged, and pending assets |
| Worker Advance History | Shows advances and scheduled deductions |
| Worker Ledger | Shows immutable financial credits and debits |
| Full & Final Settlement | Reviews and authorizes a worker exit settlement |
| Attendance | Daily organization/site attendance view |
| Mark Attendance | Glove-friendly bulk marking flow with site and date context |
| Attendance Details | Shows status, shifts, GPS, photo proof, marker, and audit data |
| Attendance Correction Request | Lets a worker submit a correction with reason and evidence |
| Attendance Correction Review | Lets an authorized user approve or reject a request |
| Attendance Conflict Review | Resolves conflicting offline attendance records |
| Sites | Searchable site directory and operational status |
| Add / Edit Site | Creates or changes site, geofence, client, and assignments |
| Site Details | Overview with attendance, labor, costs, proofs, and status |
| Site Assignments | Assigns or reassigns workers and supervisors |
| Site Attendance | Shows site-specific attendance trends and daily roster |
| Site Progress Proofs | Shows timestamped, geo-tagged progress photos |
| Site Assets | Shows allocated assets and transfer actions |
| Site Materials | Shows stock, transactions, and low-stock state |
| Site Expenses | Shows site expense register |
| Site Cost Summary | Combines labour, material, and expense cost views |

### 16.4 Finance Screens

| Screen | Purpose |
|---|---|
| Payroll | Pay-cycle list, statuses, estimates, and quick actions |
| Create Pay Cycle | Defines weekly, bi-weekly, monthly, or custom cycle |
| Payroll Details / Pay Run | Reviews calculated totals, exceptions, and approval state |
| Payroll Worker Breakdown | Reviews an individual worker’s additions, deductions, arrears, and net pay |
| Salary Rules | Configures effective-dated worker rate rules |
| Payroll Calculation Review | Presents warnings and requires review before approval |
| Pay Slip | Presents or exports a worker’s itemized pay slip |
| Payments | Searchable payment register |
| Create Payment | Prepares a payment or batch from approved payroll data |
| Payment Details | Shows amount, method, recipient, status, and audit events |
| Payment Confirmation | Requires explicit confirmation of payment breakdown before submission |
| Batch Payments | Reviews multiple payout instructions before submission |
| Payment Retry | Creates a new payment for an unsuccessful transfer; never edits the failed one |
| Payment Audit Trail | Shows immutable payment events and adjustments |
| Advances | Lists and filters advance requests, approvals, and deductions |
| Advance Request / Review | Submits or reviews an advance against the allowed limit |
| Expenses | Searchable expense register |
| Add Expense | Captures amount, category, site, payer, receipt, and notes |
| Expense Details | Shows receipt, approval, reimbursement, and audit state |
| Expense Approval | Approves or rejects a submitted expense |
| Reimbursement | Links an approved expense to a payment record |
| Receipt Viewer | Securely previews submitted receipt evidence |

### 16.5 Operations and Relationship Screens

| Screen | Purpose |
|---|---|
| Assets | Searchable asset registry |
| Add / Edit Asset | Captures asset identity, condition, location, and photo |
| Asset Details | Shows asset profile, current custody, and lifecycle history |
| Issue Asset | Records issuance, condition, and worker acknowledgement |
| Return Asset | Records return inspection and condition |
| Transfer Asset | Records transfer between sites or storage |
| Damage / Loss Report | Captures proof and sends an item for review |
| Damage / Loss Review | Determines follow-up and optional payroll deduction draft |
| Materials | Material catalog and inventory overview |
| Add / Edit Material | Defines material category, unit, and reorder threshold |
| Site Stock | Shows current material stock by site |
| Material Transaction | Records inward, consumption, transfer, wastage, or return |
| Material Delivery Proof | Captures delivery evidence, receipt, and vendor link |
| Low-stock Alerts | Prioritizes materials below threshold |
| Clients | Searchable client directory |
| Add / Edit Client | Captures client contact, tax, billing, and contract data |
| Client Details | Shows client sites, contract context, and notes |
| Vendors | Searchable supplier directory |
| Add / Edit Vendor | Captures supplier contacts, tax, bank, and categories |
| Vendor Details | Shows supplied materials, linked deliveries, and payment history |
| Vendor Payment History | Shows vendor payment records and references |

### 16.6 Intelligence, Organization, and Support Screens

| Screen | Purpose |
|---|---|
| Reports | Report library, saved filters, and exports |
| Attendance Report | Attendance by worker, site, and time period |
| Payroll Report | Pay-cycle and worker payroll analysis |
| Payment Report | Payment status, method, date, and approver report |
| Expense Report | Category and site expense analysis |
| Asset Report | Allocation, condition, damage, and utilization report |
| Material Report | Stock, consumption, and wastage report |
| Site Cost Report | Combined labour, material, and expense report |
| Worker Ledger Report | Complete worker financial history report |
| Compliance Report | Payroll and labour-law export where configured |
| Export Preview | Confirms report parameters before PDF or CSV generation |
| Profile | Personal account, device, and session preferences |
| Settings | Settings landing page grouped by responsibility |
| Organization Settings | Organization identity, financial year, and defaults |
| User Management | Invites, changes roles, deactivates users, and reviews scopes |
| Attendance & Payroll Settings | Defines shifts, holidays, rates, and approval rules |
| Payment & Expense Settings | Defines thresholds, methods, and approval rules |
| Notification Settings | Sets in-app and push notification preferences |
| Language & Appearance | Sets language, theme, contrast, type scale, and motion preference |
| Integration Settings | Configures payment, storage, and external integrations |
| Billing | Owner-only subscription and billing management |
| Audit Log | Filters immutable organization events |
| Help & Support | Guides, contact path, and diagnostic information |
| AI Settings | Enables AI, explains data boundaries, and manages suggestions |

---

## 17. User Roles and Role-Aware Navigation

### 17.1 Canonical Design Roles

The product documents currently use `Staff` and `Viewer`. This design system uses the user-facing labels `Worker` and `Guest` respectively; implementation must retain these as aliases until the RBAC schema is deliberately migrated. `Manager` is a planned operational role and must be added to the authorization model before it is exposed in product UI.

| Role | Accessible Workspaces | Primary Permissions | Restrictions | Navigation Emphasis |
|---|---|---|---|---|
| Owner | All | Full organization, approval, audit, billing, and configuration authority | Cannot hard-delete financial records or edit approved payments | Full desktop tree; all mobile workspaces |
| Admin | All except Billing | Manages operations, users, configuration, records, and approvals | Cannot manage subscription/billing or bypass immutable financial rules | Dashboard, Workforce, Finance, Operations, Intelligence |
| Manager | Workforce, Finance, Operations, Intelligence | Oversees assigned business area, reviews exceptions, submits operational records | No billing, role management, organization deletion, or payment approval unless explicitly delegated | Dashboard, Approvals, Sites, Workers, Reports |
| Supervisor | Assigned sites only | Marks attendance, manages assigned rosters, records material/asset operations, submits expenses, reviews scoped corrections | Cannot access other sites, payroll configuration, payments, financial totals, users, or organization settings | Dashboard, Sites, Attendance, Workers, More |
| Accountant | Finance, Reports, view-only operational context | Runs payroll, creates payments, manages expenses/vendors, exports financial reports | Cannot approve payroll/payment, manage workforce records, or organization settings | Dashboard, Payroll, Payments, Expenses, Reports |
| Worker | Personal workspace only | Views own attendance, payments, pay slips, profile, and submits correction/advance requests | Cannot see coworkers, site finances, approved payment records of others, or approve anything | My Work, Attendance, Payments, Profile, Help |
| Guest | Approved read-only dashboard and reports | Views explicitly shared organizational summaries and reports | Cannot create, edit, export restricted data, approve, see PII, or access AI data queries | Dashboard, Reports, Profile, Help |

### 17.2 Permission and Restriction Rules

- Permissions are deny-by-default and enforced by the API; UI visibility never substitutes for authorization.
- Site scope is applied to every Supervisor and scoped Manager query, export, search result, notification, and AI context.
- Financial actions always declare the current status and available next action. Approved payments and completed pay runs are locked; adjustment flows create new, linked records with audit history.
- Workers can only correct or request action on their own records. Guests never see worker names, contact details, bank details, documents, or granular financial records unless a future explicit sharing policy says otherwise.
- The Approvals screen shows only actionable items. A role cannot infer the existence of an inaccessible record from a badge, search result, or notification.
- Role changes take effect on the next authorization check. The interface must immediately remove no-longer-authorized routes and cached sensitive data.

### 17.3 Navigation Differences

The sidebar, mobile tabs, quick actions, search filters, Command Center commands, dashboard widgets, and notification deep links are all generated from the same role and scope policy. Do not duplicate role lists separately in each feature. A user who has no action on a module sees no primary navigation item; a read-only user sees “View” language, never disabled controls that imply unavailable authority.

---

## 18. Mobile UX Rules

### 18.1 Field-First Operation

- Mobile is optimized for high-frequency field tasks: attendance, evidence capture, roster review, site updates, and personal self-service.
- Every primary touch target is at least 48 × 48 dp, including icon-only controls. The most common attendance status choices are large, high-contrast, and reachable with one hand.
- The mobile bottom navigation remains visible on top-level screens, respects safe areas, and never contains more than five role-aware destinations.
- A persistent floating AI button sits above the bottom navigation, avoids primary submit controls, and collapses while a keyboard, modal, camera, or destructive confirmation is active.

### 18.2 Gestures, Sheets, and FABs

- Swipe is an enhancement, not the only way to complete an action. Provide explicit controls for all destructive, approval, and status-changing actions.
- Use horizontal swipes only for switching peer views (for example, attendance date or profile tabs); reveal the next view during the gesture and preserve scroll position.
- Bottom sheets handle short, contextual selections: attendance status, filters, assignment, quick actions, and sharing. They include a visible drag handle, a close control, a clear title, and a 48 dp minimum action row.
- Use one context-sensitive FAB per screen only. It represents the dominant safe action, such as “Mark attendance,” “Add expense,” or “Add worker.” It must not duplicate a persistent navigation control.

### 18.3 Search, Device Capabilities, and Connection State

- Global search is accessible from the top app bar and More; it searches locally cached data first and labels results that may be incomplete while offline.
- Offline state is persistent but quiet: display an `Offline` badge in the app bar and a compact queue count only when pending work exists. Never use a blocking full-screen offline message for supported offline workflows.
- Sync state is visible at the record level: `Saved offline`, `Syncing`, `Synced`, `Needs review`, or `Upload failed`. Status uses text and icon, never color alone.
- Camera requests occur just before capture and state why proof is needed. If denied, explain the consequence and provide Settings recovery; do not silently fall back to an unverified record when photo proof is mandatory.
- GPS requests use the same just-in-time pattern. Show accuracy and geofence status, allow a documented reason when authorized policy permits an override, and never expose precise location beyond necessary role scope.
- Voice input is optional, visible as a microphone control with recording state, transcript review, language awareness, and a typed alternative. No voice clip is submitted or used by AI until the user confirms the transcript/action.

---

## 19. Desktop UX Rules

- The desktop sidebar is the durable operating map: 280 px expanded, 80 px collapsed, keyboard-focusable, and persistent per user. Collapse preserves tooltips, active state, and readable group structure.
- The Command Center is available from every authenticated desktop route with `Ctrl/Cmd + K`. It supports navigation, permitted creation, role-scoped search, and read-only AI questions; it never bypasses approval steps.
- Core keyboard shortcuts: `Ctrl/Cmd + K` Command Center, `/` search, `g then d` dashboard, `g then w` workers, `g then a` attendance, `g then s` sites, `g then p` payroll, `?` shortcut help, and `Esc` close the current transient surface. Shortcuts must not activate while the user is typing in a text field unless explicitly intended.
- Search results group records, commands, reports, and help. They obey role, organization, site scope, and sensitive-data redaction before rendering.
- Notifications open from the header, preserve unread count with a text label for assistive technology, and deep-link to the accessible record or an explanatory unavailable state.
- The profile menu contains profile, language/appearance, active sessions where supported, help, and sign out. Organization settings remain in the Organization workspace, not hidden in the personal menu.
- Desktop tables support sticky headers, stable column widths, per-user column visibility, resizable non-essential columns, sort/filter state in the URL, and horizontal scrolling without clipping actions. Row click opens details; inline actions remain explicitly labeled on focus.
- Filters use a visible active-count, removable chips, saved views for high-value workflows, and clear-all. Persist only personal, non-sensitive view preferences.
- Bulk actions appear only after selection, state the affected count and scope, require confirmation for financial/destructive changes, and present per-record failures without losing the selection.

---

## 20. Accessibility Requirements

PayMuster targets WCAG 2.2 AA as the baseline and uses AAA contrast where practical for field legibility. Accessibility is a product requirement for every screen, not a final review step.

### 20.1 Visual Accessibility

- High-contrast mode increases surface separation, text contrast, focus-ring prominence, and status distinction without changing business meaning. It is available from first-run preferences and Settings.
- Status always combines color with text, icon, and where needed a pattern or label: for example, `Present` with check icon, `Absent` with cross icon, `Pending` with clock icon.
- Interfaces must remain understandable for common red-green, blue-yellow, and monochrome color vision differences. No workflow may depend on interpreting an unlabelled color swatch.
- Support system large-text settings and in-app text scaling through 200% without truncating data, hiding controls, or requiring two-dimensional page scrolling at standard desktop width.

### 20.2 Keyboard and Assistive Technology

- All desktop tasks are operable by keyboard in a logical visual order. Focus is visible, never obscured, and returns to the triggering element when a dialog or sheet closes.
- Dialogs, sheets, menus, command palette, date pickers, and comboboxes use correct semantics, trap focus only while open, and expose an Escape action when safe.
- Use semantic HTML first. Every icon-only control has a meaningful accessible name; every input has a persistent label, error text, required state, and programmatically associated help text.
- Screen-reader announcements describe async progress, sync result, validation summary, successful save, and error recovery. Announcements must be concise and must not expose sensitive values unexpectedly.
- Motion reduction respects operating-system preference and the in-app setting. It removes nonessential movement, shimmer, and animated counting while retaining immediate state feedback.

---

## 21. Localization Rules

### 21.1 Supported Languages and Content Ownership

Initial supported languages are English (`en-IN`), Hindi (`hi-IN` / हिन्दी), and Punjabi (`pa-IN` / ਪੰਜਾਬੀ). All customer-facing static text, validation messages, status labels, help, notifications, and AI interface framing use centralized message keys; text must never be embedded directly in a component.

Company names, worker names, legal names, addresses, document identifiers, bank data, site names, asset tags, material names entered by the organization, and other user-created proper nouns are never translated or transliterated automatically. The UI may display a pronunciation/accessibility hint only when the source data explicitly provides one.

### 21.2 Dates, Numbers, and Currency

- Store dates, timestamps, money, measurements, and identifiers in locale-neutral data formats. Format at presentation time using the selected locale and organization settings.
- Default date presentation is unambiguous: `29 Jul 2026`; date pickers additionally expose the localized full date. Use timezone-aware timestamps and clearly label the site/organization timezone when dates affect payroll or attendance.
- Use Indian grouping for INR by default: `₹4,82,000.00`. Currency code must be available in exports, large totals, and when organization currency can differ from INR.
- Preserve numeric input as digits internally while allowing familiar localized display. Never parse a formatted string as the source of truth. Units (kg, bags, metres, litres) remain explicit and non-translated only where industry-standard; otherwise their label is localized.
- Use ICU plural/select rules for every counted message. Do not construct plural sentences by concatenating translated fragments; Hindi and Punjabi messages must have their own grammatical forms.

### 21.3 Layout and Validation

- Design for text expansion of at least 35% from English. Labels wrap before they truncate; critical amounts, dates, statuses, and primary actions never truncate.
- Translate the user-facing names of roles, status labels, and modules, while preserving canonical identifiers for URLs, audit records, and permissions.
- Locale changes apply immediately to formatting and new content. Historic audit data preserves the original raw values and may be rendered in the current language without rewriting the record.

---

## 22. Offline and Sync Rules

Offline-first is an experience promise. The user must always know whether an action is safely saved, awaiting upload, needs review, or requires a connection.

### 22.1 Status Model

| Status | Meaning | UI Treatment |
|---|---|---|
| Online / Synced | Latest known data is confirmed by server | Quiet check indicator; no persistent banner |
| Offline | Device has no usable connection | App-bar badge and supported actions remain available |
| Saved offline | Local record is durable and queued | Record-level status with queued timestamp |
| Syncing | Queue or upload is in progress | Non-blocking progress indicator; user may continue working |
| Upload pending | Media proof awaits connection or upload | Queue item with file count and retry state |
| Needs review | Server conflict or policy rejection requires attention | Persistent, actionable status and notification |
| Sync failed | Retry limit or local error reached | Clear reason, retry control, and support path |

### 22.2 Offline Capability Boundaries

- Attendance marking, GPS/photo proof capture, site roster viewing, assigned worker viewing, correction drafts, and authorized operational transaction drafts must work from local storage.
- Locally captured evidence is retained securely and linked to its draft record before upload. The app must not report a proof-backed record as fully synced until its required media is uploaded and accepted.
- Financial approvals, payment submission, pay-run approval, role changes, billing, and other server-authoritative actions require a live connection. Explain why and allow the user to save a non-authoritative draft when appropriate.
- The Offline Queue is available from sync status and Settings. It lists pending uploads and records without exposing protected data to a user who no longer has permission.

### 22.3 Retry and Conflict Resolution

- Retry automatically with exponential backoff after connection returns, subject to battery and operating-system limits. Show the next retry only after repeated failure; never imply a record is lost.
- Non-financial conflicts use the documented last-write-wins policy only when that policy does not remove required evidence or user intent. Display the resulting resolution in the record history.
- Financial data is server-authoritative. The client cannot overwrite it offline.
- Conflicting attendance records require manual resolution by an authorized Admin, Owner, or scoped Supervisor where policy permits. The review shows both values, timestamps, marker identities, proof links, and a mandatory resolution reason.
- A conflict resolution creates an immutable audit event and resolves the queue item only after the server accepts it.

---

## 23. Animation System

Motion communicates causality, hierarchy, and completion. It never decorates at the expense of speed, legibility, battery, or field use.

### 23.1 Motion Tokens and Page Transitions

| Token | Duration | Use |
|---|---:|---|
| Instant | 0–100 ms | Press acknowledgement, focus change |
| Fast | 150 ms | Button, checkbox, icon state |
| Standard | 200 ms | Menus, sheets, cards, route content |
| Deliberate | 300 ms | Page transition, modal, success handoff |

Use ease-out for entering elements and ease-in for exiting elements. Page transitions are a short opacity transition with a maximum 8 px directional shift when navigation direction is meaningful. Do not animate full-page layouts on data refresh, filter changes, or table sorting.

### 23.2 Component Behavior

- Buttons: press provides immediate contrast and a maximum 0.98 scale change; disabled state does not animate; loading preserves width and label context.
- Cards: hover on desktop only lifts by no more than 2 px or changes surface/border contrast. Interactive cards expose the same state on keyboard focus. Cards never float theatrically.
- Lists and tables: new confirmed records may receive one brief highlight; do not animate every row or shuffle content without user intent.
- Loading: use skeletons shaped like the pending content. Shimmer is subtle and disabled for reduced motion. Use a determinate progress indicator for uploads and lengthy calculations.
- Empty states: fade in once with no looping illustration. The CTA appears with the state, not as a delayed surprise.
- Success: show a concise toast and, when the task changes location, a calm route transition to the completed record. Financial and approval success states include a reference and next step.
- Error: surface the failed region without shaking, flashing, or moving focus unexpectedly. Keep user-entered data, explain recovery, and animate only the appearance of the error summary.

### 23.3 Reduced Motion

With reduced motion enabled, use instant state changes or opacity-only transitions under 100 ms. Disable shimmer, scaling, counting, spring effects, autoplay, looping illustrations, and nonessential map movement. The information hierarchy and success/error feedback must remain fully clear.

---

## 24. Illustration and Icon Rules

### 24.1 Brand and Logo

- Use the approved PayMuster logo asset only. Preserve its proportions, contrast, and a clear space at least equal to the mark’s smallest internal unit.
- Do not redraw, stretch, rotate, outline, add gradients to, or place the logo on low-contrast imagery. Use the approved monochrome variant only when the full-color mark fails contrast requirements.
- The logo identifies the product; it is not a decorative watermark, loading spinner, background pattern, or substitute for a navigation icon.

### 24.2 Icons and Construction Vocabulary

- Use Lucide icons as the primary web icon set. Mobile uses platform-native equivalents only when their metaphor and stroke weight match the shared icon specification.
- Icons are functional, familiar, and paired with labels for navigation and consequential actions. Tooltips support icon-only desktop controls; mobile icon-only controls require accessible labels and sufficient context.
- Prefer clear construction metaphors: hard hat, site pin, worker, clipboard, clock, wallet, receipt, wrench, package, truck, building, shield, camera, location, and sparkles for AI. Never use a decorative icon that changes the meaning of a status.
- Do not mix filled, outlined, 3D, hand-drawn, emoji, or multicolour icon families in the same surface. Status icons use the semantic color token plus text.

### 24.3 Illustration, Photography, and Avatars

- Illustrations are reserved for onboarding, empty states, help, and recoverable errors. They use restrained geometric forms, realistic construction cues, dark-compatible surfaces, and no childish characters or exaggerated expressions.
- Photography is documentary and operational: real workers with PPE, sites, tools, materials, and evidence. Obtain consent, avoid stock-photo poses, and never use faces as decorative backgrounds behind data.
- Worker avatars default to an uploaded, consented profile photograph. When absent, use initials on a high-contrast neutral surface; never use random faces, gendered silhouettes, or playful generated characters.
- Empty-state illustrations must reinforce the action: an empty roster, a mapped site, a clean receipt folder, or organized tools. They remain secondary to clear copy and CTA.

---

## 25. Design Principles

Every screen and component should feel professional, calm, trustworthy, premium, fast, minimal, readable, and construction-friendly.

- **Professional**: Present business information with precise language, stable hierarchy, deliberate spacing, and no gimmicks.
- **Calm**: Limit simultaneous alerts, reserve strong color for status/action, and make errors recoverable without panic.
- **Trustworthy**: Show status, proof, source, timestamp, actor, and audit history wherever decisions or money require confidence.
- **Premium**: Use excellent typography, consistent surfaces, subtle depth, and intentional whitespace—not visual excess.
- **Fast**: Prioritize direct actions, optimistic local save where safe, keyboard efficiency on desktop, and immediate touch feedback on mobile.
- **Minimal**: Remove decorative chrome and repeated labels. Retain context, labels, and safeguards that prevent costly mistakes.
- **Readable**: Make important values, statuses, dates, and actions scannable in bright field conditions and dense office workflows.
- **Construction-friendly**: Design for gloves, glare, intermittent connection, multilingual teams, evidence capture, and real operational pressure.

The product must never become playful, a gaming UI, neon cyberpunk, or a generic Tailwind dashboard. Avoid dashboards made from visually identical metric cards, gratuitous gradients, glowing borders, glassmorphism, mascot-led screens, confetti, dark patterns, or productivity-theatre animations. Industrial does not mean harsh: warmth comes from human language, trustworthy evidence, and good pacing.

---

## 26. Future Expansion Rules

The design system is a contract for extension. Every new module, screen, workflow, and platform must inherit the existing foundations without rewriting them.

1. **Tokens and theme**: Use semantic design tokens only. A new module may propose tokens through design review; it may not add raw colors, arbitrary spacing, shadows, typography, or ad hoc dark-mode values.
2. **Language**: Add centralized messages for English, Hindi, and Punjabi before release. Preserve user-entered proper nouns and use the shared date, number, currency, and pluralization rules.
3. **Navigation**: Register routes, desktop/mobile placement, deep links, command palette terms, search metadata, and role visibility in the shared information architecture. Do not create a disconnected mini-application.
4. **Permissions**: Declare each page, action, data field, export, notification, AI context, and offline operation in the shared permission model. Deny access by default and apply scope everywhere.
5. **Motion and states**: Implement shared interaction tokens and explicit loading, empty, error, success, permission, offline, syncing, and conflict states. Reduced-motion behavior is required from the first design.
6. **Offline and audit**: Define what can work locally, what must wait for the server, media upload behavior, retry/merge policy, and audit events before building a workflow.
7. **Accessibility**: Meet the accessibility requirements at component and screen design time. A module cannot introduce inaccessible custom controls, color-only status, or keyboard dead ends.
8. **Documentation review**: Update this screen inventory, information architecture, role matrix, and component specification when a module changes shared behavior. A feature is not design-complete until those changes are reviewed.

---

## Implementation Checklist

- [ ] Color tokens defined in CSS/Tailwind/Flutter constants
- [ ] Typography scale implemented across platforms
- [ ] Spacing scale enforced globally (no random padding)
- [ ] All components built per spec (button, card, input, etc.)
- [ ] Dark/Light/AMOLED themes implemented
- [ ] Responsive breakpoints tested
- [ ] Accessibility audit (WCAG AA minimum)
- [ ] Animations smooth at 60 FPS
- [ ] Micro-interactions polished
- [ ] Storybook/component library documented

---

**Next**: Stop here. Wait for approval before proceeding to Theme System (Step 2).
