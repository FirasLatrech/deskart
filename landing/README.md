# DeskArt landing page

Next.js 16 + Tailwind v4 + motion. Deployed to Vercel.

## Develop

```bash
npm install
npm run dev
```

## Shape geometry

The shapes drawn on this page are not illustrations — they are exported from
DeskArt's own placement engine, so the site shows the exact points the app will
place icons on. Regenerate after changing the engine:

```bash
# from the repository root
swift scripts/export-shapes.swift landing/shapes.json
```

then convert to `src/lib/shapes.ts` (see the header comment in that file).

## Notes

- The headline gradient's dark stops are deliberately lifted above the page
  background. A ramp bottoming out near `#091020` leaves the word invisible for
  much of its 6s sweep against a `#0c0c0c` canvas.
- The ambient backdrop is CSS gradients rather than a background video: a
  fullscreen loop costs megabytes and battery on a page whose subject is a
  static grid of dots.
- Shape switching animates `cx`/`cy` per dot with a keyed index, so a change
  reads as a rearrangement rather than a swap. It pauses off-screen, on hidden
  tabs, and under `prefers-reduced-motion`.
