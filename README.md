# DeskArt

A native macOS menu bar app that arranges your Desktop icons into shapes.

## Run

```bash
swift build -c release
.build/release/DeskArt
```

The app lives in the menu bar (sparkles icon) — no Dock icon, no window.

## What it does

Reads your Desktop icons via Finder, computes target positions for a chosen
shape, writes them back, then **reads them back again to verify**. Every apply
takes an automatic snapshot first, so any arrangement is undoable.

15 shapes, grouped in the menu by family:

| Family | Shapes |
| --- | --- |
| Typographic | **Text** — any string through a 3×5 bitmap font |
| Classic | Circle, Grid, Diamond, Double Ring |
| Playful | Star, Smiley, Arrow, Infinity, Heart |
| Organic | Flower, Wave, Spiral, Butterfly, Scatter |

The 🎲 button next to the picker picks a random shape (never repeating the
current one, so it always visibly does something).

## The parts

| File | Role |
| --- | --- |
| `FinderBridge.swift` | All Finder I/O. Batched reads/writes, name escaping, verify-with-tolerance |
| `ScreenMapper.swift` | Cocoa ⇄ Finder coordinate conversion, per display |
| `Shapes.swift` | 3×5 bitmap font + geometric point generators |
| `Placer.swift` | Fits a shape to a display under the spacing floor |
| `Snapshots.swift` | Save/restore icon positions (JSON in Application Support) |
| `AppModel.swift` / `ContentView.swift` | State and the menu bar UI |

## UI decisions

- **Finder I/O never runs on the main actor.** An apply is several Apple Event
  round trips taking ~2s; inline, it froze the menu and the `busy` flag was set
  and cleared within one synchronous call, so the spinner could never render.
  All Finder work now hops off-actor via `Task.detached`, verified to execute
  correctly off the main thread.
- **Apple Events are serialized** on one queue. Off-main execution works, but
  overlapping scripts could interleave a read with a write — a menu-open refresh
  landing mid-apply would read half-moved positions and report a false verify
  failure.
- **Notes carry severity.** "25 icons parked in the corner" is `info`, not a
  warning: showing normal bookkeeping with the same orange alarm as "your text
  is too wide" trains the user to ignore both.
- **Undo sits next to Arrange**, not behind the history panel — it is the
  reassurance that makes Arrange safe to press.
- **Deleting a snapshot confirms first.** It is the only way back to a previous
  arrangement.
- **A checkmark appears only where something was verified.** A neutral status
  like "46 icons on the Desktop" gets `info.circle`, because a checkmark there
  would claim a confirmation that never happened.
- Icon-only buttons carry `accessibilityLabel`; counts use monospaced digits so
  they don't jitter as they change.
- **The preview legend sits below the canvas, not inside it.** As a
  bottom-trailing overlay it landed directly on top of the parked dots it was
  labelling. It doubles as the count readout so the same numbers aren't
  repeated under the buttons and again in a note.

### Leftover icons get their own space, reserved up front

With 26 of 46 icons parked, the corner block needs ~408pt of width — but a
full-width "HI" leaves only 258pt free beside it, so the block had nowhere to go
but on top of the glyphs. Two changes fix it:

1. `cornerGrid` fills a **square-ish block** instead of complete rows. Row-major
   filling turned 26 leftovers into a band spanning the entire display, which
   competed with the shape instead of reading as set-aside icons.
2. The drawing area is **shrunk before the shape is laid out**, reserving room
   for the block. Height only — taking width would squeeze text glyphs, which
   need horizontal room most — capped at 40% so the figure never becomes a
   sliver.

Note the leftover count must come from `pts.count`, not `fittingCount`: for text
the fitting count is the whole icon list regardless of how few cells the glyphs
light up, so deriving it there reports 0 leftovers and reserves nothing.

Verified across 45 combinations: zero shape/parked bounding-box overlaps, every
icon still placed, 68pt floor intact.

## Things that will bite you

Each of these was verified experimentally on a three-display setup, not assumed.

### Coordinates

Finder's desktop space and Cocoa's screen space differ in a way that fails
*silently* — icons just appear on the wrong monitor.

- **Cocoa** (`NSScreen.frame`): origin at the **main** screen's bottom-left,
  y increasing **upward**. Screens to the left have negative x.
- **Finder** (`desktop position`): shares x, but y increases **downward** from
  the **main** screen's **top** edge.

```
finderY = mainScreen.maxY - cocoaY
```

The main screen is the reference for *every* display, not each screen's own
frame. Verified by writing y=1200 to a display whose Cocoa frame is y=37…1117
and watching Finder clamp it to exactly 1080 (= 1117 − 37).

**Never** use `bounds of window of desktop` to size a layout — it returns the
union of all displays (here `-1920, 0, 3648, 1117`), so anything fitted to it
spills across monitors. Enumerate `NSScreen.screens` and target one frame.

### Icons don't scale

A Desktop icon occupies a fixed ~64pt footprint no matter how large the layout
is. So a shape is **never** shrunk to fit — shrinking only overlaps icons into
an unreadable blob. When a shape doesn't fit, the **icon count** drops instead.

`minSpacing` is 68pt (64pt footprint + 4pt of air).

### Plan at 69.5pt, not 68pt

Finder stores **integer** positions, so every coordinate is rounded on write.
Two points can each round outward, shrinking a gap by up to √2 ≈ 1.41pt. Planning
against a bare 68pt ships pairs that measure **67.2pt** once written — confirmed
by reading a real circle back out of Finder. `planningSpacing` budgets the
rounding loss so the *stored* positions honour the floor.

### Choose the count, then generate

Generating N points and culling the crowded ones mangles the shape: a circle
sized for 45 icons has ~65pt gaps, so a greedy cull drops every other one and
leaves ragged ~130pt holes. Instead, binary-search the largest count whose
generated points *already* satisfy spacing, then generate exactly that many.

This took the circle from 22 unevenly spaced icons to 42 evenly spaced ones.

`enforceSpacing` remains as a final safety net that should drop nothing.

### Self-intersecting curves defeat a naive fit search

Flower, Infinity and Butterfly pass through their own centre, so two points far
apart *along the curve* can land on top of each other *in space* — Infinity at
n=20 produces a pair exactly **0.0pt** apart. Shrinking the figure cannot
separate them, so a search on raw minimum distance collapses the whole shape to
fix one crossing: Flower bottomed out at **7 usable icons** of 46.

The fix is to search on *adjacent* spacing (consecutive points along the path),
which is what actually controls legibility, and let `enforceSpacing` remove the
crossing points locally. That costs one or two icons instead of the figure:

| Shape | Before | After |
| --- | --- | --- |
| Flower | 7 | 21 |
| Infinity | 14 | 39 |
| Butterfly | 7 | 27 |

Composite shapes (Smiley, Double Ring, Scatter) aren't traced paths — their
points aren't in path order, so "adjacent" is meaningless and they use true
minimum distance instead.

### Arc-length sampling, not uniform t

Curves are sampled by arc length. Uniform parameter *t* bunches icons wherever
the curve turns sharply — the star's spikes, the butterfly's wings — which reads
as clumping and wastes the spacing budget.

Scatter uses a golden-angle (sunflower) distribution rather than true
randomness: random points clump, and clumps are exactly what the 68pt floor
would then delete. Deterministic also means the preview matches what lands.

### Petal count is a legibility decision

A typical Desktop yields ~21 icons for Flower. At that budget 6 lobes smear into
a ring of scattered dots while 4 stay individually readable, so the rose curve
uses k=2. Same reasoning as the density warning: legibility beats density.

### No global relaxation

Overlaps are resolved by **dropping** offending points, never by nudging the
cloud. A force-directed pass has nowhere to push on a crowded screen and
flattens the design globally; dropping is local, so surviving points stay
exactly where the shape wanted them.

### Finder name quirks

`.app` bundles report **without** the `.app` extension, and Finder treats them
as folders. Always round-trip through Finder's names, never `FileManager`'s.
Names are escaped for `"` and `\` before going into AppleScript.

### Reading positions

`repeat with t in (every item of desktop)` yields a reference that won't coerce
— it fails with error −1700. Iterate by index instead.

Results are joined with `|||`, not commas: a comma-joined list silently breaks
on any filename containing a comma and yields garbage offsets.

### Sorting must be off

If the Desktop has Sort By or Use Stacks enabled, writes succeed and Finder
immediately re-sorts them. The app checks `arrangement of icon view options`
and refuses to apply unless it reads "not arranged".

### Verify, with tolerance

`try` blocks swallow failures, so a run that moved nothing looks identical to a
successful one. Positions are always read back and compared — at **±10pt**, not
equality, because Finder rounds and snaps by a point or two.

## Text scaling

Each lit font cell can expand into a *k*×*k* block of icons, so a short string
absorbs a large icon count instead of parking most of them. *k* is the largest
integer where `litCells × k² ≤ iconCount` and the glyphs still fit the display.

Scaling is integer-only by design — fractional scaling would push icons off the
68pt lattice and reintroduce the crowding the lattice prevents.

Leftovers that the shape can't use are parked in a bottom-right corner grid.

## Distribution

Not sandboxed — Apple Events to Finder are incompatible with the App Store
sandbox. `Info.plist` (with `NSAppleEventsUsageDescription`) is embedded into
the binary via `-sectcreate`, using an **absolute** path: the linker resolves
relative paths from its own working directory and will silently embed an empty
section otherwise.

On first run macOS prompts for Automation access to Finder. Running from a
terminal that already has the grant inherits it.
