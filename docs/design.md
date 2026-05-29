---
name: ShiftTac Premium Design System
colors:
  surface: '#f6faf8'
  surface-dim: '#d6dbd9'
  surface-bright: '#f6faf8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f5f3'
  surface-container: '#eaefed'
  surface-container-high: '#e4e9e7'
  surface-container-highest: '#dfe3e2'
  on-surface: '#171d1c'
  on-surface-variant: '#3d4947'
  inverse-surface: '#2c3130'
  inverse-on-surface: '#edf2f0'
  outline: '#6d7a77'
  outline-variant: '#bcc9c6'
  surface-tint: '#006a63'
  primary: '#006a63'
  on-primary: '#ffffff'
  primary-container: '#3aa89e'
  on-primary-container: '#003733'
  inverse-primary: '#6fd8cd'
  secondary: '#a7392a'
  on-secondary: '#ffffff'
  secondary-container: '#fd7865'
  on-secondary-container: '#701008'
  tertiary: '#94492c'
  on-tertiary: '#ffffff'
  tertiary-container: '#da815f'
  on-tertiary-container: '#591d03'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#8cf4e9'
  primary-fixed-dim: '#6fd8cd'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#00504a'
  secondary-fixed: '#ffdad4'
  secondary-fixed-dim: '#ffb4a8'
  on-secondary-fixed: '#410100'
  on-secondary-fixed-variant: '#862116'
  tertiary-fixed: '#ffdbcf'
  tertiary-fixed-dim: '#ffb59a'
  on-tertiary-fixed: '#380d00'
  on-tertiary-fixed-variant: '#763317'
  background: '#f6faf8'
  on-background: '#171d1c'
  surface-variant: '#dfe3e2'
  background-warm: '#F7F4EC'
  surface-mist: '#CFE8E2'
  primary-pressed: '#1E5E5A'
  accent-gold: '#FFC857'
  ink-navy: '#1D2330'
  faded-mark-opacity: '0.45'
typography:
  display-lg:
    fontFamily: Poppins
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  title-md:
    fontFamily: Poppins
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  headline-sm:
    fontFamily: Poppins
    fontSize: 20px
    fontWeight: '500'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Nunito Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Nunito Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-bold:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Nunito Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: '1.2'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 24px
  grid-gutter: 12px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

<!-- markdownlint-configure-file {"MD024": {"siblings_only": true}} -->

# ShiftTac — Complete UI/UX Design Specification

## Product Vision

ShiftTac is a premium casual strategy game built around a simple but endlessly evolving mechanic:

> Every move changes the board.

The experience should feel:

* Elegant
* Strategic
* Calm
* Smart
* Tactile
* Modern
* Timeless

NOT:

* Loud arcade
* Childish
* Hyper competitive
* Overly futuristic
* Visually chaotic

The UI should feel like:

> “A beautifully crafted strategy object.”

---

## 1. EXPERIENCE PRINCIPLES

## Core UX Goals

### 1. Immediate Understanding

The player should understand:

* It starts like normal ShiftTac
* Marks disappear
* The faded mark is important

within the first 30 seconds.

---

### 2. Calm Strategy

The interface must support thinking and anticipation.

Avoid:

* Noise
* Excessive motion
* Visual clutter

Prefer:

* Space
* Focus
* Breathing room

---

### 3. Tactile Interaction

Every tap should feel responsive and physical.

Interactions should feel:

* Soft
* Smooth
* Intentional

---

### 4. Gameplay First

The board is always the hero.

Everything else supports:

* clarity
* anticipation
* readability

---

## 2. BRAND FOUNDATION

## Brand Name

### ShiftTac

---

## Brand Statement

> Every move changes the board.

---

## Supporting Messaging

### Gameplay

* Think ahead.
* The board evolves.
* Your oldest move fades.
* One move changes everything.

### Win Messages

* Smart play.
* Perfect timing.
* You saw it coming.

### Onboarding

* Simple to learn.
* Infinite to master.

---

## 3. VISUAL IDENTITY

## Design Personality

The interface should feel:

* Soft
* Geometric
* Intelligent
* Balanced
* Airy
* Minimal

---

## Shape Language

Use:

* Rounded corners
* Soft rectangles
* Gentle shadows
* Balanced spacing

Avoid:

* Sharp corners
* Heavy borders
* Aggressive shapes

---

## 4. COLOR SYSTEM

## Primary Palette

### Warm Ivory

`#F7F4EC`
Purpose:

* Main background
* Eye comfort
* Softness

---

### Soft Mist

`#CFE8E2`
Purpose:

* Secondary surfaces
* Layering
* Card backgrounds

---

### Teal

`#3AA89E`
Purpose:

* Player O
* Primary CTA
* Highlights
* Turn indicators

---

### Deep Teal

`#1E5E5A`
Purpose:

* Pressed states
* Focus states
* Strategic emphasis

---

### Soft Coral

`#FF7A66`
Purpose:

* Player X
* Energy
* Friendly competition

---

### Warm Gold

`#FFC857`
Purpose:

* Rewards
* Celebration
* Important highlights

Use sparingly.

---

### Ink Navy

`#1D2330`
Purpose:

* Typography
* Core icons
* Main UI contrast

---

## 5. COLOR USAGE RULES

## Backgrounds

Always warm and breathable.

NEVER:

* pure white
* harsh black

---

## Gameplay Balance

X and O must feel equally important visually.

No color dominance.

---

## Faded Mark Rules

Current player's oldest mark:

* 40–50% opacity
* slightly desaturated
* smooth fade animation

This is one of the MOST IMPORTANT gameplay visuals.

---

## 6. TYPOGRAPHY SYSTEM

## Primary Typeface

### Poppins

Use for:

* headings
* titles
* buttons
* navigation

Weights:

* Medium
* SemiBold

---

## Secondary Typeface

### Nunito Sans

Use for:

* descriptions
* onboarding text
* settings
* helper labels

---

## Typography Rules

### Titles

* Large
* Clean spacing
* Minimal clutter

### Body Text

* Comfortable line height
* Calm tone
* Easy readability

---

## 7. ICONOGRAPHY

Icons should be:

* Thin
* Rounded
* Outline-based
* Minimal

Avoid:

* Gaming-style icons
* Aggressive shapes
* Heavy fills

---

## 8. MOTION SYSTEM

## Motion Principles

### Smooth

Nothing snaps harshly.

### Calm

Motion should never feel chaotic.

### Tactile

Every interaction feels touch-responsive.

---

## Timing

### Tap Feedback

120–160ms

### Move Placement

180–220ms

### Fade Removal

220–280ms

### Dialog Entrance

250–320ms

---

## Animations

### New Move

* scale pop
* slight bounce

### Removed Move

* dissolve fade
* subtle shrink

### Turn Switch

* label slide
* card glow transition

### Winning Line

* soft pulse
* glow reveal

Avoid:

* explosive effects
* loud celebration animations

---

## 9. APP FLOW

```text
Splash
↓
Onboarding (3 Screens)
↓
Home
↓
Gameplay
↓
Win Dialog
↓
Replay or Home
```

Optional:

* Skip onboarding
* Instant replay

No account system.

---

## 10. SCREEN SPECIFICATIONS

### SPLASH SCREEN

#### Goal

Introduce identity instantly.

---

#### Layout

##### Center

Infinity logo with embedded:

* X
* O

##### Title

ShiftTac

##### Subtitle

“The board never fills.”

---

#### Bottom

Either:

* Tap to Start
  OR
* subtle loading animation

---

#### Background

Warm Ivory with:

* faded X/O shapes
* soft gradients

---

#### Animation

Infinity logo:

* slow rotation
  OR
* flowing infinity motion

Duration:
2–3 seconds max

---

### ONBOARDING SCREEN 1

#### Goal

Show familiarity.

---

#### Visual

Classic 3×3 board.

---

#### Text

##### Title

Looks familiar?

##### Description

It starts like classic ShiftTac…

---

#### Bottom

* progress indicator
* next button

---

### ONBOARDING SCREEN 2

#### Goal

Explain 3 active marks rule.

---

#### Visual Sequence

1. 3 active marks
2. 4th move placed
3. oldest mark disappears

Use animated mini-board.

---

#### Text

##### Title

Only 3 marks stay active

##### Description

Your oldest move disappears when you place a new one.

---

### ONBOARDING SCREEN 3

#### Goal

Teach faded mark mechanic.

MOST IMPORTANT onboarding screen.

---

#### Visual

Board with:

* faded oldest mark
* normal active marks

---

#### Text

##### Title

Watch the faded mark

##### Description

The faded mark shows which move disappears next.

---

#### Bottom

* Back
* Start Playing

---

### HOME SCREEN

#### Goal

Central hub.

---

#### Layout

##### Top

* small infinity logo
* game title
* subtitle:
  “Offline Multiplayer Strategy Game”

---

#### Main Area

##### Primary CTA

Play ShiftTac Multiplayer

Description:
Play with a friend on the same device

---

##### Secondary CTA

Play vs AI

Can show:

* disabled state
* “Coming Soon”

---

##### Additional Buttons

* How to Play
* Settings

---

#### Bottom

* version
* credits

---

#### Visual Style

Should feel:

* premium
* strategic
* playful minimalism

---

### GAMEPLAY SCREEN

MOST IMPORTANT SCREEN.

---

#### Layout Structure

##### Top Header

###### Left

Back button

###### Center

Infinity logo

###### Right

Restart button

Optional:
Settings icon

---

#### Turn Section

Large animated turn indicator.

Examples:

* X’s Turn
* O’s Turn

Should animate during turn switch.

---

#### Move Counter

Example:
Moves: 7

Minimal pill-style container.

---

#### Game Board

##### Requirements

* fixed 3×3 grid
* centered
* responsive
* large tap targets

---

#### Cell States

##### Empty

* neutral border
* soft shadow

---

##### Active Mark

* full opacity
* crisp
* centered

---

##### Faded Oldest Mark

Critical gameplay indicator.

Requirements:

* 40–50% opacity
* soft fade
* subtle glow optional

Only current player's oldest mark fades.

---

#### Board Design

##### Style

* floating appearance
* soft borders
* subtle elevation

---

##### Cell Design

* rounded corners
* minimal shadows
* tactile press feedback

---

#### Gameplay Animations

##### Valid Move

* scale pop
* soft bounce

##### Invalid Move

* subtle shake
* optional haptic feedback

##### Removed Move

* fade dissolve
* shrink transition

##### Winning Line

* glow
* pulse
* line highlight

---

#### Player Panels

Bottom section.

---

##### Player X Card

Contains:

* symbol
* active status
* turn highlight

If active:

* glow border
* elevated appearance

---

##### Player O Card

Same structure.

---

#### Win State

When win occurs:

* freeze board
* show win animation
* open dialog

---

### WIN DIALOG

#### Layout

##### Top

Large animated winner symbol.

---

#### Title

* X Wins!
* O Wins!

---

#### Optional Stats

* total moves
* match duration

---

#### Buttons

##### Primary

Play Again

##### Secondary

Back to Home

---

#### Effects

Optional:

* subtle confetti
* warm glow

Avoid excessive celebration.

---

### PAUSE MENU

Bottom sheet style.

---

#### Options

* Resume
* Restart Match
* How to Play
* Settings
* Exit to Home

---

### HOW TO PLAY SCREEN

Visual-first teaching.

Avoid long paragraphs.

---

#### Sections

##### 1

Classic board

---

##### 2

3 active marks only

---

##### 3

Oldest mark fades

---

##### 4

4th move removes oldest

---

##### 5

Get 3 in a row to win

---

#### Best Practice

Use:

* animated mini boards
* step-by-step visual examples

---

### SETTINGS SCREEN

Keep lightweight.

---

#### Sections

##### Theme

* Light
* Dark

##### Audio

* Sound effects
* Music

##### Gameplay

* Vibration

##### About

* Version
* Credits

---

## 11. GAMEPLAY UX RULES

### Occupied Cell Tap

* ignore input
* subtle shake animation

---

### During Animations

Temporarily prevent rapid taps.

---

### Win Logic UX

After win:

* stop interactions
* display result clearly

---

## 12. TECHNICAL UI REQUIREMENTS

### Board

Fixed 3×3.

---

### Active Marks

Each player max:
3 active marks.

---

### FIFO Logic

When 4th move happens:

1. remove oldest
2. place new move
3. check win

---

### Visual Queue System

The fading mark MUST clearly indicate:
“this mark disappears next.”

---

## 13. RESPONSIVE DESIGN

### Small Phones

Maintain:

* centered board
* readable turn labels
* large tap targets

---

### Tablets

Increase:

* spacing
* board scale
* card sizes

Avoid stretched layouts.

---

## 14. ACCESSIBILITY

### Requirements

* readable contrast
* large touch targets
* clear turn indicators

---

### Avoid

* relying only on color
* tiny labels
* cluttered interfaces

---

## 15. AUDIO DIRECTION

### Sound Style

Soft and tactile.

---

### Sounds

#### Placement

Soft click/pop

#### Removal

Gentle dissolve

#### Win

Elegant chime

---

### Avoid

* casino sounds
* arcade noise
* aggressive impacts

---

## 16. APP ICON

### Structure

Minimal infinity symbol.

---

### Background

Warm ivory or soft gradient.

---

### Goal

Instant recognition at small sizes.

---

## 17. DESIGN KEYWORDS

Always align decisions with:

* Elegant
* Strategic
* Infinite
* Calm
* Minimal
* Tactile
* Smart
* Smooth
* Timeless
* Social

---

## 18. FINAL CREATIVE DIRECTION

The final product should feel like:

* a modern board game
* a premium strategy toy
* a calm competitive experience

The disappearing FIFO mechanic already creates tension naturally.

The UI should support the mechanic —
never overpower it.
