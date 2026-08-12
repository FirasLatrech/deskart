import AppKit

/// Turns a normalized shape into concrete Finder positions on one display.
///
/// The governing rule: **icons do not scale.** A Desktop icon occupies a fixed
/// footprint (~64pt for the tile plus its label) no matter how large or small
/// the layout is. So a shape can never be shrunk to fit — shrinking only makes
/// icons overlap into an unreadable blob. When a shape does not fit, the
/// *icon count* is reduced instead, never the spacing.
enum Placer {

    /// Hard floor on centre-to-centre distance. 64pt icon footprint + 4pt of
    /// air, so neighbouring labels never collide.
    static let minSpacing: CGFloat = 68

    /// Spacing actually required of unrounded points.
    ///
    /// Finder stores integer positions, so `apply` rounds every coordinate.
    /// Two points can each round outward by up to 0.5pt in x and y, shrinking a
    /// gap by up to √2 ≈ 1.41pt. Planning against a bare 68pt therefore ships
    /// pairs that measure ~67.2pt once written. Budget the rounding loss here
    /// so the *stored* positions honour the floor.
    static let planningSpacing: CGFloat = 68 + 1.5

    /// Severity of a plan note. Parking leftover icons is normal bookkeeping,
    /// not a problem — showing it with the same alarm styling as "your text is
    /// too wide" trains the user to ignore both.
    enum NoteLevel { case info, warning }

    struct Note: Hashable {
        var level: NoteLevel
        var text: String
    }

    struct Plan {
        /// name -> Finder-space position, ready to apply.
        var placements: [String: CGPoint] = [:]
        /// Icons that form the shape itself.
        var shapeCount: Int = 0
        /// Icons parked in the corner grid because the shape could not use them.
        var parkedCount: Int = 0
        /// Icons the shape asked for but that we do not have.
        var shortfall: Int = 0
        var notes: [Note] = []
        /// Only the notes that signal something the user may want to act on.
        var warnings: [String] { notes.filter { $0.level == .warning }.map(\.text) }
        /// Points actually used by the shape, for the preview.
        var previewShape: [CGPoint] = []
        var previewParked: [CGPoint] = []
    }

    /// Builds a full placement plan.
    ///
    /// - Parameters:
    ///   - names: Finder names of the icons to arrange, in the order they
    ///     should fill the shape.
    static func plan(
        shape: Shape,
        text: String,
        names: [String],
        mapper: ScreenMapper
    ) -> Plan {
        var plan = Plan()
        guard !names.isEmpty else {
            plan.notes.append(Note(level: .warning, text: "There are no icons on the Desktop to arrange."))
            return plan
        }

        // Inset by half an icon so no tile is clipped by the screen edge.
        let pad = minSpacing / 2 + 8
        let box = mapper.finderRect.insetBy(dx: pad, dy: pad)
        guard box.width > minSpacing, box.height > minSpacing else {
            plan.notes.append(Note(level: .warning, text: "This display is too small to arrange icons on."))
            return plan
        }

        // 1. Decide how many icons the shape can actually carry, *then*
        //    generate that many.
        //
        //    Generating `names.count` points and culling the crowded ones is
        //    wrong: on a circle sized for 45 icons the points sit ~65pt apart,
        //    so a greedy cull drops every other one and leaves ragged ~130pt
        //    gaps. Choosing the count up front means the generator emits an
        //    evenly spaced ring that needs no culling at all.
        let requested = fittingCount(shape: shape, text: text, available: names.count, box: box)
        // Thicken glyph strokes to use the icons we actually have.
        let kScale = shape == .text ? textScale(text: text, available: names.count, box: box) : 1
        let pts = ShapeGenerator.points(
            shape: shape, count: requested, text: text, textScale: kScale
        )

        if shape == .text {
            if pts.isEmpty {
                plan.notes.append(Note(level: .warning, text:
                    text.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Type some text to render."
                    : "None of those characters are in the 3x5 font."
                ))
                return plan
            }
            // Text has a fixed cell structure, so instead of scaling the shape
            // we check whether that structure fits at full spacing — and if it
            // does not, we tell the user to shorten the string rather than
            // quietly squeezing the glyphs together.
            let cw = CGFloat(BitmapFont.cellWidth(for: text) * kScale)
            let ch = CGFloat(BitmapFont.height * kScale)
            let cell = min(box.width / cw, box.height / ch)
            if cell < planningSpacing {
                let maxChars = maxCharacters(box: box)
                plan.notes.append(Note(level: .warning, text:
                    "“\(text)” is too wide for \(mapper.displayName) at readable spacing. "
                    + "Use about \(maxChars) character\(maxChars == 1 ? "" : "s") or fewer."
                ))
                return plan
            }
        }

        // 2. Reserve a corner for leftovers *before* laying out the shape.
        //
        //    Otherwise the shape claims the whole display and the parked block
        //    has nowhere to go but on top of it: with 26 leftovers the block
        //    needs ~408pt of width, while a full-width "HI" leaves only 258pt
        //    free beside it. Shrinking the drawing area is the honest trade —
        //    the figure gets slightly smaller, but nothing overlaps it.
        //    `pts.count` is the true number the shape will consume. Deriving it
        //    from `fittingCount` instead would read 0 leftovers for text, whose
        //    fitting count is the whole icon list regardless of how few cells
        //    the glyphs actually light up.
        let leftoverEstimate = max(names.count - pts.count, 0)
        let drawBox = shrinkForParking(box: box, leftovers: leftoverEstimate, shape: shape)

        // 3. Map normalized points onto the display, preserving aspect ratio so
        //    circles stay round.
        var mapped = mapAspectFit(pts, into: drawBox, shape: shape, text: text)

        // 3. Enforce spacing by *dropping* offenders — never by nudging the
        //    whole cloud. A global relaxation pass has nowhere to push on a
        //    crowded screen and flattens the design into a blob; a local drop
        //    keeps the surviving points exactly where the shape wanted them.
        mapped = enforceSpacing(mapped)

        // 4. Assign icons to points.
        let usable = min(names.count, mapped.count)
        plan.shapeCount = usable
        plan.previewShape = Array(mapped.prefix(usable))
        for (i, p) in mapped.prefix(usable).enumerated() {
            plan.placements[names[i]] = p
        }

        if mapped.count > names.count {
            plan.shortfall = mapped.count - names.count
            plan.notes.append(Note(level: .warning, text:
                "This shape needs \(mapped.count) icons but only \(names.count) are on the Desktop — "
                + "the outline will be incomplete."
            ))
        }

        // 5. Park leftovers in a tidy corner grid rather than leaving them
        //    wherever they happened to be, which would read as noise around
        //    the design.
        let leftovers = Array(names.dropFirst(usable))
        if !leftovers.isEmpty {
            let parked = cornerGrid(count: leftovers.count, box: box, avoiding: plan.previewShape)
            for (i, p) in parked.enumerated() where i < leftovers.count {
                plan.placements[leftovers[i]] = p
            }
            plan.parkedCount = min(parked.count, leftovers.count)
            plan.previewParked = parked
            if plan.parkedCount < leftovers.count {
                plan.notes.append(Note(level: .warning, text:
                    "\(leftovers.count - plan.parkedCount) icon(s) could not be placed — the display is full."
                ))
            } else {
                // Informational: parking is the designed behaviour for icons
                // the shape cannot use, not a problem to fix.
                plan.notes.append(Note(level: .info, text:
                    "\(plan.parkedCount) leftover icon\(plan.parkedCount == 1 ? "" : "s") parked in the corner."
                ))
            }
        }

        // Legibility beats density: a sparse shape reads, a crammed one does not.
        if shape != .text && shape != .grid && shape != .scatter && usable > 60 {
            plan.notes.append(Note(level: .info, text:
                "\(usable) icons is dense for this shape — it may read better with fewer."
            ))
        }

        return plan
    }

    /// Largest icon count whose generated points already satisfy `minSpacing`.
    ///
    /// Binary search rather than a closed form, because it works uniformly for
    /// every parametric shape (circle perimeter, heart arc length, spiral
    /// pitch) without a bespoke formula per shape — and it is measured against
    /// the *mapped* points, so it accounts for the target display's size.
    private static func fittingCount(
        shape: Shape, text: String, available: Int, box: CGRect
    ) -> Int {
        switch shape {
        case .text:
            // Text is a lattice, not a curve: it fits or it does not, and the
            // block scale (below) decides how many icons it consumes.
            return available
        case .grid:
            // The grid generator already sizes itself to n.
            return available
        case .smiley, .ring, .scatter:
            // Not single traced paths — their points are not in path order, so
            // "adjacent" is meaningless. They allocate their own sub-features
            // and spread evenly, so measure true minimum distance.
            var lo = 1, hi = available, best = 1
            while lo <= hi {
                let mid = (lo + hi) / 2
                let mapped = mapAspectFit(
                    ShapeGenerator.points(shape: shape, count: mid, text: text),
                    into: box, shape: shape, text: text
                )
                if minPairDistance(mapped) >= planningSpacing {
                    best = mid
                    lo = mid + 1
                } else {
                    hi = mid - 1
                }
            }
            return best
        default:
            // Self-intersecting curves (flower petals, the infinity crossing,
            // butterfly wings) pass through their own centre, so two points far
            // apart *along the curve* can coincide *in space* — Infinity at
            // n=20 produces a pair exactly 0.0pt apart. Shrinking the shape
            // cannot separate them, so a search on raw minimum distance
            // collapses the whole figure to fix one crossing: flower bottomed
            // out at 7 usable icons.
            //
            // So the search ignores collisions between curve-distant points and
            // measures only *adjacent* spacing, which is what actually controls
            // legibility. The crossing points are then removed locally by
            // `enforceSpacing`, costing one or two icons instead of the figure.
            var lo = 1, hi = available, best = 1
            while lo <= hi {
                let mid = (lo + hi) / 2
                let mapped = mapAspectFit(
                    ShapeGenerator.points(shape: shape, count: mid, text: text),
                    into: box, shape: shape, text: text
                )
                if minAdjacentDistance(mapped, closed: shape != .wave) >= planningSpacing {
                    best = mid
                    lo = mid + 1
                } else {
                    hi = mid - 1
                }
            }
            return best
        }
    }

    /// Smallest distance between consecutive points along a traced path.
    private static func minAdjacentDistance(_ pts: [CGPoint], closed: Bool) -> CGFloat {
        guard pts.count > 1 else { return .infinity }
        var m = CGFloat.infinity
        for i in 0..<(pts.count - 1) {
            m = min(m, hypot(pts[i].x - pts[i+1].x, pts[i].y - pts[i+1].y))
        }
        if closed, let f = pts.first, let l = pts.last {
            m = min(m, hypot(f.x - l.x, f.y - l.y))
        }
        return m
    }

    /// Smallest centre-to-centre distance in a point set.
    private static func minPairDistance(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count > 1 else { return .infinity }
        var m = CGFloat.infinity
        for i in 0..<pts.count {
            for j in (i + 1)..<pts.count {
                m = min(m, hypot(pts[i].x - pts[j].x, pts[i].y - pts[j].y))
            }
        }
        return m
    }

    /// Largest integer block scale for rendering `text`: each lit cell becomes
    /// a k x k block of icons, so a short string on a crowded Desktop uses the
    /// icons it has instead of parking most of them in the corner.
    ///
    /// Integer-only by design. Fractional scaling would put icons off the 68pt
    /// lattice and reintroduce the crowding the lattice exists to prevent.
    static func textScale(text: String, available: Int, box: CGRect) -> Int {
        let lit = BitmapFont.cells(for: text).count
        guard lit > 0 else { return 1 }
        let cw = CGFloat(BitmapFont.cellWidth(for: text))
        let ch = CGFloat(BitmapFont.height)
        var best = 1
        for k in 1...8 {
            let fitsIcons = lit * k * k <= available
            let fitsBox = cw * CGFloat(k) * minSpacing <= box.width
                       && ch * CGFloat(k) * minSpacing <= box.height
            if fitsIcons && fitsBox { best = k } else { break }
        }
        return best
    }

    /// Largest character count that still fits at full spacing on this box.
    static func maxCharacters(box: CGRect) -> Int {
        // Each glyph costs 4 cells of width (3 + 1 gap), minus the trailing gap.
        // Height must also clear 5 cells at minSpacing.
        guard box.height >= minSpacing * CGFloat(BitmapFont.height) else { return 0 }
        let cellsWide = box.width / minSpacing
        return max(Int((cellsWide + 1) / CGFloat(BitmapFont.width + 1)), 0)
    }

    /// Maps normalized points into `box` without distorting the shape.
    private static func mapAspectFit(
        _ pts: [CGPoint], into box: CGRect, shape: Shape, text: String
    ) -> [CGPoint] {
        guard !pts.isEmpty else { return [] }

        // Text keeps the font's own aspect ratio; other shapes are square in
        // normalized space.
        let aspect: CGFloat
        if shape == .text {
            aspect = CGFloat(max(BitmapFont.cellWidth(for: text), 1)) / CGFloat(BitmapFont.height)
        } else {
            aspect = 1
        }

        var w = box.width
        var h = w / aspect
        if h > box.height {
            h = box.height
            w = h * aspect
        }
        let originX = box.midX - w / 2
        let originY = box.midY - h / 2
        return pts.map { CGPoint(x: originX + $0.x * w, y: originY + $0.y * h) }
    }

    /// Greedily keeps points that respect `minSpacing`, discarding any that
    /// would sit too close to one already kept.
    ///
    /// This is intentionally *not* a relaxation/force-directed pass. Relaxation
    /// resolves overlap by pushing every point, which on a full screen has
    /// nowhere to go and destroys the shape globally. Dropping is local: the
    /// points that survive are untouched.
    private static func enforceSpacing(_ pts: [CGPoint]) -> [CGPoint] {
        var kept: [CGPoint] = []
        kept.reserveCapacity(pts.count)
        for p in pts {
            var ok = true
            for q in kept where hypot(p.x - q.x, p.y - q.y) < planningSpacing {
                ok = false
                break
            }
            if ok { kept.append(p) }
        }
        return kept
    }

    /// Shrinks the drawing area so a corner block of `leftovers` icons fits
    /// beside the shape rather than on top of it.
    ///
    /// Only the height is reduced: taking width would squeeze text glyphs,
    /// which are the shapes most sensitive to horizontal room. The reduction is
    /// capped at 40% so the figure never becomes a sliver — past that point the
    /// block is allowed to sit closer instead.
    private static func shrinkForParking(box: CGRect, leftovers: Int, shape: Shape) -> CGRect {
        guard leftovers > 0 else { return box }
        let cols = max(Int(ceil(sqrt(Double(leftovers)))), 1)
        let rows = Int(ceil(Double(leftovers) / Double(cols)))
        let needed = CGFloat(rows) * minSpacing + minSpacing / 2
        let maxShrink = box.height * 0.4
        let cut = min(needed, maxShrink)
        return CGRect(x: box.minX, y: box.minY, width: box.width, height: box.height - cut)
    }

    /// Packs leftover icons into a compact block in the bottom-right corner,
    /// skipping any cell that would crowd the shape itself.
    ///
    /// The block is kept roughly square rather than filling each row across the
    /// full screen width. A row-major fill turns 26 leftovers into a band
    /// spanning the whole display, which competes with the shape for attention
    /// instead of reading as set-aside icons.
    private static func cornerGrid(count: Int, box: CGRect, avoiding shape: [CGPoint]) -> [CGPoint] {
        guard count > 0 else { return [] }
        let step = minSpacing
        let maxCols = max(Int(box.width / step), 1)
        let maxRows = max(Int(box.height / step), 1)
        // Square-ish block, capped by what the display can actually hold.
        let cols = min(max(Int(ceil(sqrt(Double(count)))), 1), maxCols)
        let rows = min(max(Int(ceil(Double(count) / Double(cols))) + 1, 1), maxRows)
        var out: [CGPoint] = []

        // Extent of the figure, used to keep the block outside it entirely.
        let shapeBounds: CGRect? = shape.isEmpty ? nil : {
            let xs = shape.map(\.x), ys = shape.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!,
                          width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }()

        // Walk bottom-right to top-left so the block hugs the corner.
        outer: for r in 0..<rows {
            for c in 0..<cols {
                let p = CGPoint(x: box.maxX - CGFloat(c) * step,
                                y: box.maxY - CGFloat(r) * step)
                // Keeping the block out of the shape's bounding box, not merely
                // 68pt from its nearest icon: a block that satisfies spacing can
                // still sit *inside* the figure's extent and read as part of it.
                if let bb = shapeBounds, bb.insetBy(dx: -step / 2, dy: -step / 2).contains(p) { continue }
                // Shape points are unrounded, so clear them by the rounding-safe
                // margin — parked-to-parked cells are integer multiples of
                // `step` and cannot compound, but parked-to-shape can.
                if shape.contains(where: { hypot(p.x - $0.x, p.y - $0.y) < planningSpacing }) { continue }
                if out.contains(where: { hypot(p.x - $0.x, p.y - $0.y) < step }) { continue }
                out.append(p)
                if out.count == count { break outer }
            }
        }

        // The square block is a preference, not a constraint: if the shape
        // blocked enough cells that some icons are still unplaced, widen to the
        // full grid so nothing is left behind.
        if out.count < count {
            outer2: for r in 0..<maxRows {
                for c in 0..<maxCols {
                    let p = CGPoint(x: box.maxX - CGFloat(c) * step,
                                    y: box.maxY - CGFloat(r) * step)
                    if shape.contains(where: { hypot(p.x - $0.x, p.y - $0.y) < planningSpacing }) { continue }
                    if out.contains(where: { hypot(p.x - $0.x, p.y - $0.y) < step }) { continue }
                    out.append(p)
                    if out.count == count { break outer2 }
                }
            }
        }
        return out
    }
}
