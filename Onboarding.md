# Onboarding - Style Guidelines

## Paper Grainy Background (Page Level)

The main page background uses a paper texture effect applied via the `.paper-texture` CSS class. This creates a subtle grainy, paper-like appearance across the entire viewport.

### Implementation

**Location:** `apps/web/site/src/app/globals.css`

**CSS Class:** `.paper-texture`

### Style Specifications

#### Base Layer
- **Background Color:** `#ffffff` (pure white)
- **Position:** `relative` (required for pseudo-element positioning)

#### Grain/Noise Layer (::before pseudo-element)
- **Content:** Empty string (pseudo-element only)
- **Position:** `absolute` covering full container (`top: 0, left: 0, width: 100%, height: 100%`)
- **Z-index:** `0` (behind all content)
- **Pointer Events:** `none` (doesn't interfere with interactions)

**Noise Texture:**
- **Type:** SVG-based fractal noise using `feTurbulence`
- **Base Frequency:** `0.9` (controls the scale of the noise pattern - higher = finer grain)
- **Number of Octaves:** `4` (controls the detail/complexity of the noise)
- **Stitch Tiles:** `stitch` (ensures seamless tiling)
- **Opacity:** `0.3` (30% opacity for subtle effect)

**SVG Data URI:**
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%">
  <filter id="noise">
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="4" stitchTiles="stitch" />
  </filter>
  <rect width="100%" height="100%" filter="url(#noise)" opacity="0.3" />
</svg>
```

### Usage
Applied to the root container in `HomeClient.tsx`:
```tsx
<div className="h-screen w-screen paper-texture relative overflow-hidden">
```

---

## Instructions Component Background

The Instructions component uses a multi-layered vintage paper effect that simulates aged, worn paper with grid lines, corner wear, edge darkening, and grain texture.

### Implementation

**Location:** `apps/web/site/src/components/Instructions.tsx`

### Style Specifications

#### Layer 1: Base Paper with Grid
- **Background Color:** `#faf9f6` (warm off-white, slightly cream-toned)
- **Grid Pattern:** 
  - Two linear gradients creating horizontal and vertical lines
  - Line color: `rgba(0,0,0,0.03)` (very subtle black at 3% opacity)
  - Line width: `1px`
  - Grid size: `20px × 20px` (spacing between grid lines)
- **Padding:** `p-8` (32px padding on all sides)

**CSS:**
```css
backgroundImage: `
  linear-gradient(to right, rgba(0,0,0,0.03) 1px, transparent 1px),
  linear-gradient(to bottom, rgba(0,0,0,0.03) 1px, transparent 1px)
`;
backgroundSize: "20px 20px";
```

#### Layer 2: Corner Wear (Z-index: 1)
Four radial gradients positioned at each corner to simulate paper wear and aging:

- **Top-left corner:**
  - Ellipse: `80px × 80px`
  - Position: `8px 8px`
  - Color: `rgba(255, 245, 230, 0.4)` fading to transparent
  - Fade distance: `70%`

- **Top-right corner:**
  - Ellipse: `70px × 70px`
  - Position: `calc(100% - 8px) 8px`
  - Color: `rgba(255, 245, 230, 0.3)` fading to transparent
  - Fade distance: `60%`

- **Bottom-left corner:**
  - Ellipse: `90px × 90px`
  - Position: `8px calc(100% - 8px)`
  - Color: `rgba(255, 248, 235, 0.35)` fading to transparent
  - Fade distance: `70%`

- **Bottom-right corner:**
  - Ellipse: `100px × 100px`
  - Position: `calc(100% - 8px) calc(100% - 8px)`
  - Color: `rgba(255, 250, 240, 0.45)` fading to transparent
  - Fade distance: `70%`

**Pointer Events:** `none` (doesn't interfere with interactions)

#### Layer 3: Edge Darkening (Z-index: 2)
Four linear gradients on each edge to create subtle shadowing:

- **Left edge:** `90deg` gradient, `rgba(0,0,0,0.02)` fading to transparent over `3%`
- **Right edge:** `270deg` gradient, `rgba(0,0,0,0.015)` fading to transparent over `2%`
- **Top edge:** `0deg` gradient, `rgba(0,0,0,0.02)` fading to transparent over `3%`
- **Bottom edge:** `180deg` gradient, `rgba(0,0,0,0.015)` fading to transparent over `2%`

**Pointer Events:** `none`

#### Layer 4: Noise/Grain Texture (Z-index: 3)
- **Type:** SVG-based fractal noise using `feTurbulence`
- **Base Frequency:** `1.2` (finer grain than page background)
- **Number of Octaves:** `5` (more detail than page background)
- **Stitch Tiles:** `stitch` (seamless tiling)
- **Opacity:** `0.03` (very subtle at 3% opacity)
- **Blend Mode:** `multiply` (darkens the underlying layers)

**SVG Data URI:**
```svg
<svg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'>
  <filter id='noise'>
    <feTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/>
  </filter>
  <rect width='100%' height='100%' filter='url(#noise)'/>
</svg>
```

**Pointer Events:** `none`

### Additional Styling

The Instructions component also includes:
- **Drop Shadow:** Multiple layered shadows for depth:
  - `drop-shadow(0px 1px 1px rgba(0,0,0,0.1))`
  - `drop-shadow(0px 2px 4px rgba(0,0,0,0.08))`
  - `drop-shadow(0px 4px 8px rgba(0,0,0,0.06))`
- **Font Family:** `var(--font-ibm-plex-mono), monospace`
- **Opacity:** `1` (fully opaque)

### Layer Stacking Order
1. Base paper with grid (background layer)
2. Corner wear (z-index: 1)
3. Edge darkening (z-index: 2)
4. Noise/grain (z-index: 3)
5. Content (z-index: 10)

---

## Key Differences

| Aspect | Page Background | Instructions Background |
|--------|----------------|------------------------|
| **Base Color** | `#ffffff` (pure white) | `#faf9f6` (warm off-white) |
| **Grid Pattern** | None | 20px × 20px grid |
| **Aging Effects** | None | Corner wear + edge darkening |
| **Noise Frequency** | `0.9` | `1.2` (finer) |
| **Noise Octaves** | `4` | `5` (more detail) |
| **Noise Opacity** | `0.3` | `0.03` (much subtler) |
| **Blend Mode** | Normal | Multiply (on noise layer) |
| **Complexity** | Simple single layer | Multi-layered vintage effect |

