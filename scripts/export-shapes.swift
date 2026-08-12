import CoreGraphics
import Foundation

/// A shape emits points in a normalized space where x and y both run 0…1,
/// y pointing down (same sense as Finder). The placer maps them onto a display.
///
/// Shapes describe *ideal* geometry and are deliberately unaware of icon size:
/// the placer owns spacing, because only it knows the target screen.
enum Shape: String, CaseIterable, Identifiable {
    case text, circle, heart, spiral, grid
    case star, flower, wave, diamond, infinity, arrow, smiley, ring, butterfly, scatter
    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Text"
        case .circle: return "Circle"
        case .heart: return "Heart"
        case .spiral: return "Spiral"
        case .grid: return "Grid"
        case .star: return "Star"
        case .flower: return "Flower"
        case .wave: return "Wave"
        case .diamond: return "Diamond"
        case .infinity: return "Infinity"
        case .arrow: return "Arrow"
        case .smiley: return "Smiley"
        case .ring: return "Double Ring"
        case .butterfly: return "Butterfly"
        case .scatter: return "Scatter"
        }
    }

    var needsText: Bool { self == .text }

    /// SF Symbol for the menu, so shapes are scannable by icon as well as name.
    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .circle: return "circle"
        case .heart: return "heart"
        case .spiral: return "hurricane"
        case .grid: return "square.grid.3x3"
        case .star: return "star"
        case .flower: return "camera.macro"
        case .wave: return "waveform"
        case .diamond: return "diamond"
        case .infinity: return "infinity"
        case .arrow: return "arrow.right"
        case .smiley: return "face.smiling"
        case .ring: return "circle.circle"
        case .butterfly: return "ant"
        case .scatter: return "sparkles"
        }
    }

    /// Grouped for the menu, so fifteen entries stay browsable.
    enum Family: String, CaseIterable { case typographic, classic, playful, organic }

    var family: Family {
        switch self {
        case .text: return .typographic
        case .circle, .grid, .diamond, .ring: return .classic
        case .star, .smiley, .arrow, .infinity, .heart: return .playful
        case .flower, .wave, .spiral, .butterfly, .scatter: return .organic
        }
    }

    /// Shapes worth offering to "Surprise Me". Text needs a string and grid is
    /// the boring baseline, so neither is a fun random pick.
    static var randomizable: [Shape] {
        allCases.filter { $0 != .text && $0 != .grid }
    }
}

// MARK: - 3x5 bitmap font

/// A 3-wide, 5-tall bitmap font. One lit cell becomes one icon.
///
/// 3x5 is the smallest grid in which every letter and digit stays
/// distinguishable — at 68pt spacing a single glyph is already ~136x272pt, so
/// anything larger would fit only a couple of characters on screen.
enum BitmapFont {
    static let width = 3
    static let height = 5

    /// Rows are top-to-bottom, each a 3-character mask.
    static let glyphs: [Character: [String]] = [
        "A": ["010", "101", "111", "101", "101"],
        "B": ["110", "101", "110", "101", "110"],
        "C": ["011", "100", "100", "100", "011"],
        "D": ["110", "101", "101", "101", "110"],
        "E": ["111", "100", "110", "100", "111"],
        "F": ["111", "100", "110", "100", "100"],
        "G": ["011", "100", "101", "101", "011"],
        "H": ["101", "101", "111", "101", "101"],
        "I": ["111", "010", "010", "010", "111"],
        "J": ["001", "001", "001", "101", "010"],
        "K": ["101", "101", "110", "101", "101"],
        "L": ["100", "100", "100", "100", "111"],
        "M": ["101", "111", "111", "101", "101"],
        "N": ["101", "111", "111", "111", "101"],
        "O": ["010", "101", "101", "101", "010"],
        "P": ["110", "101", "110", "100", "100"],
        "Q": ["010", "101", "101", "111", "011"],
        "R": ["110", "101", "110", "101", "101"],
        "S": ["011", "100", "010", "001", "110"],
        "T": ["111", "010", "010", "010", "010"],
        "U": ["101", "101", "101", "101", "011"],
        "V": ["101", "101", "101", "101", "010"],
        "W": ["101", "101", "111", "111", "101"],
        "X": ["101", "101", "010", "101", "101"],
        "Y": ["101", "101", "010", "010", "010"],
        "Z": ["111", "001", "010", "100", "111"],
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "2": ["110", "001", "010", "100", "111"],
        "3": ["110", "001", "010", "001", "110"],
        "4": ["101", "101", "111", "001", "001"],
        "5": ["111", "100", "110", "001", "110"],
        "6": ["011", "100", "111", "101", "111"],
        "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"],
        "9": ["111", "101", "111", "001", "110"],
        "!": ["010", "010", "010", "000", "010"],
        "?": ["110", "001", "010", "000", "010"],
        ".": ["000", "000", "000", "000", "010"],
        "-": ["000", "000", "111", "000", "000"],
        "+": ["000", "010", "111", "010", "000"],
        "<": ["001", "010", "100", "010", "001"],
        ">": ["100", "010", "001", "010", "100"],
        " ": ["000", "000", "000", "000", "000"],
    ]

    static func supports(_ c: Character) -> Bool {
        glyphs[Character(c.uppercased())] != nil
    }

    /// Lit cells for a string, in integer cell coordinates.
    /// Letters are separated by one blank column.
    static func cells(for text: String) -> [(x: Int, y: Int)] {
        var out: [(x: Int, y: Int)] = []
        var cursor = 0
        for ch in text.uppercased() {
            guard let g = glyphs[ch] else { continue }
            for (row, bits) in g.enumerated() {
                for (col, bit) in bits.enumerated() where bit == "1" {
                    out.append((x: cursor + col, y: row))
                }
            }
            cursor += width + 1   // one blank column between glyphs
        }
        return out
    }

    /// Total cell width of a rendered string, including inter-letter gaps.
    static func cellWidth(for text: String) -> Int {
        let n = text.count(where: { glyphs[Character($0.uppercased())] != nil })
        return n == 0 ? 0 : n * (width + 1) - 1
    }
}

// MARK: - Geometric shapes

enum ShapeGenerator {

    /// Points for `count` icons, normalized to 0…1 with y pointing down.
    /// The returned count may be *fewer* than requested when a shape has a
    /// natural structure (text); callers handle the leftovers.
    static func points(shape: Shape, count: Int, text: String, textScale: Int = 1) -> [CGPoint] {
        switch shape {
        case .text:      return textPoints(text, scale: textScale)
        case .circle:    return circlePoints(count)
        case .heart:     return heartPoints(count)
        case .spiral:    return spiralPoints(count)
        case .grid:      return gridPoints(count)
        case .star:      return starPoints(count)
        case .flower:    return flowerPoints(count)
        case .wave:      return wavePoints(count)
        case .diamond:   return diamondPoints(count)
        case .infinity:  return infinityPoints(count)
        case .arrow:     return arrowPoints(count)
        case .smiley:    return smileyPoints(count)
        case .ring:      return ringPoints(count)
        case .butterfly: return butterflyPoints(count)
        case .scatter:   return scatterPoints(count)
        }
    }

    // MARK: - Closed curves
    //
    // Anything traced along a curve is sampled by arc length via `walk`, not by
    // uniform parameter t. Uniform t bunches icons wherever the curve turns
    // sharply — the star's points, the butterfly's wings — which reads as
    // clumping and wastes the spacing budget.

    /// Five-pointed star outline, alternating outer and inner radius.
    static func starPoints(_ n: Int, points spikes: Int = 5) -> [CGPoint] {
        guard n > 0 else { return [] }
        var corners: [CGPoint] = []
        let steps = spikes * 2
        for i in 0..<steps {
            let a = 2 * .pi * CGFloat(i) / CGFloat(steps) - .pi / 2
            let r: CGFloat = i.isMultiple(of: 2) ? 0.5 : 0.20
            corners.append(CGPoint(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a)))
        }
        corners.append(corners[0])
        return normalize(walkPolyline(corners, count: n))
    }

    /// Rose curve r = |cos(kθ)|. k=2 gives four petals.
    ///
    /// Four, not six or eight: a typical Desktop yields ~21 icons for this
    /// shape, and at that budget 6 lobes smear into a ring of scattered dots
    /// while 4 stay individually readable. Legibility beats density.
    static func flowerPoints(_ n: Int, petals k: CGFloat = 2) -> [CGPoint] {
        guard n > 0 else { return [] }
        return normalize(walk(count: n, samples: 2400) { t in
            let a = t * 2 * .pi
            let r = 0.5 * abs(cos(k * a))
            return CGPoint(x: r * cos(a), y: r * sin(a))
        })
    }

    /// Lemniscate of Gerono — a clean figure-eight that stays open at the
    /// crossing instead of pinching, so the centre icons don't collide.
    static func infinityPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        return normalize(walk(count: n, samples: 2400) { t in
            let a = t * 2 * .pi
            return CGPoint(x: cos(a), y: sin(a) * cos(a))
        })
    }

    /// Butterfly curve (Fay), scaled down so the wings dominate the body.
    static func butterflyPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        return normalize(walk(count: n, samples: 4000) { t in
            let a = t * 12 * .pi
            let r = exp(cos(a)) - 2 * cos(4 * a) + pow(sin(a / 12), 5)
            return CGPoint(x: r * sin(a), y: -r * cos(a))
        })
    }

    /// Diamond / rhombus outline.
    static func diamondPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        let c: [CGPoint] = [
            CGPoint(x: 0.5, y: 0.0), CGPoint(x: 1.0, y: 0.5),
            CGPoint(x: 0.5, y: 1.0), CGPoint(x: 0.0, y: 0.5),
            CGPoint(x: 0.5, y: 0.0),
        ]
        return walkPolyline(c, count: n)
    }

    /// Two concentric rings, allocated by circumference so both end up with
    /// comparable spacing rather than a crowded inner ring.
    static func ringPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        let outerR: CGFloat = 0.5, innerR: CGFloat = 0.27
        let share = outerR / (outerR + innerR)
        let outerN = max(Int((CGFloat(n) * share).rounded()), 1)
        let innerN = max(n - outerN, 0)
        var out: [CGPoint] = []
        for i in 0..<outerN {
            let a = 2 * .pi * CGFloat(i) / CGFloat(outerN) - .pi / 2
            out.append(CGPoint(x: 0.5 + outerR * cos(a), y: 0.5 + outerR * sin(a)))
        }
        for i in 0..<innerN {
            // Offset half a step so inner icons sit between outer ones.
            let a = 2 * .pi * (CGFloat(i) + 0.5) / CGFloat(max(innerN, 1)) - .pi / 2
            out.append(CGPoint(x: 0.5 + innerR * cos(a), y: 0.5 + innerR * sin(a)))
        }
        return out
    }

    // MARK: - Open figures

    /// Sine wave across the full width, sampled by arc length so the crests
    /// aren't more crowded than the flat sections.
    static func wavePoints(_ n: Int, cycles: CGFloat = 2) -> [CGPoint] {
        guard n > 0 else { return [] }
        return normalize(walk(count: n, samples: 2400, closed: false) { t in
            CGPoint(x: t, y: 0.5 * sin(t * cycles * 2 * .pi))
        })
    }

    /// Right-pointing arrow: shaft plus head, drawn as one outline.
    static func arrowPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        let c: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.35), CGPoint(x: 0.55, y: 0.35),
            CGPoint(x: 0.55, y: 0.15), CGPoint(x: 1.00, y: 0.50),
            CGPoint(x: 0.55, y: 0.85), CGPoint(x: 0.55, y: 0.65),
            CGPoint(x: 0.00, y: 0.65), CGPoint(x: 0.00, y: 0.35),
        ]
        return walkPolyline(c, count: n)
    }

    // MARK: - Composite

    /// A face: ring, two eyes, and a smile arc.
    ///
    /// Features get a fixed icon budget rather than a proportional share —
    /// eyes are one icon each no matter the count, because two icons per eye
    /// at 68pt spacing reads as a squint, not an eye.
    static func smileyPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        var out: [CGPoint] = []
        // Eyes first so they survive if the budget is tight.
        if n >= 3 {
            out.append(CGPoint(x: 0.34, y: 0.36))
            out.append(CGPoint(x: 0.66, y: 0.36))
        }
        let smileN = max(min(n / 4, 9), 0)
        let faceN = max(n - out.count - smileN, 0)
        for i in 0..<faceN {
            let a = 2 * .pi * CGFloat(i) / CGFloat(max(faceN, 1)) - .pi / 2
            out.append(CGPoint(x: 0.5 + 0.5 * cos(a), y: 0.5 + 0.5 * sin(a)))
        }
        // Mouth: lower arc from ~200° to ~340°.
        for i in 0..<smileN {
            let t = CGFloat(i) / CGFloat(max(smileN - 1, 1))
            let a = .pi * (0.18 + 0.64 * t)
            out.append(CGPoint(x: 0.5 + 0.26 * cos(a), y: 0.52 + 0.30 * sin(a)))
        }
        return out
    }

    /// Deterministic pseudo-random scatter — an even, non-gridded fill.
    ///
    /// Uses a golden-angle (sunflower) distribution rather than true random:
    /// real randomness clumps, and clumps are exactly what the 68pt floor
    /// would then have to delete. Deterministic also means the preview matches
    /// what gets applied.
    static func scatterPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        let golden = CGFloat.pi * (3 - sqrt(5))
        return (0..<n).map { i in
            let r = 0.5 * sqrt((CGFloat(i) + 0.5) / CGFloat(n))
            let a = CGFloat(i) * golden
            return CGPoint(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a))
        }
    }

    // MARK: - Arc-length sampling helpers

    /// Samples a parametric curve at `count` equally spaced arc-length steps.
    static func walk(
        count: Int, samples: Int, closed: Bool = true, _ f: (CGFloat) -> CGPoint
    ) -> [CGPoint] {
        guard count > 0 else { return [] }
        var pts: [CGPoint] = []
        var cum: [CGFloat] = [0]
        for i in 0...samples {
            let p = f(CGFloat(i) / CGFloat(samples))
            pts.append(p)
            if i > 0 {
                cum.append(cum[i - 1] + hypot(p.x - pts[i - 1].x, p.y - pts[i - 1].y))
            }
        }
        let total = cum.last ?? 1
        guard total > 0 else { return Array(repeating: pts[0], count: count) }
        // A closed curve must not place an icon on both the start and the end
        // of the loop — they are the same location.
        let divisor = CGFloat(closed ? count : max(count - 1, 1))
        var out: [CGPoint] = []
        var j = 0
        for i in 0..<count {
            let target = total * CGFloat(i) / divisor
            while j < cum.count - 1 && cum[j] < target { j += 1 }
            out.append(pts[j])
        }
        return out
    }

    /// Arc-length walk along a polyline (corner list).
    static func walkPolyline(_ corners: [CGPoint], count: Int) -> [CGPoint] {
        guard count > 0, corners.count > 1 else { return [] }
        var segLen: [CGFloat] = []
        for i in 1..<corners.count {
            segLen.append(hypot(corners[i].x - corners[i-1].x, corners[i].y - corners[i-1].y))
        }
        let total = segLen.reduce(0, +)
        guard total > 0 else { return Array(repeating: corners[0], count: count) }
        var out: [CGPoint] = []
        for i in 0..<count {
            var d = total * CGFloat(i) / CGFloat(count)
            var s = 0
            while s < segLen.count && d > segLen[s] { d -= segLen[s]; s += 1 }
            let idx = min(s, segLen.count - 1)
            let t = segLen[idx] > 0 ? d / segLen[idx] : 0
            let a = corners[idx], b = corners[idx + 1]
            out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        return out
    }

    /// Renders text, expanding each lit cell into a `scale` x `scale` block of
    /// icons. Scale 1 is the plain 3x5 outline; higher scales thicken the
    /// strokes so a short string can absorb a large icon count instead of
    /// leaving most of them parked in a corner.
    static func textPoints(_ text: String, scale: Int = 1) -> [CGPoint] {
        let cells = BitmapFont.cells(for: text)
        guard !cells.isEmpty else { return [] }
        let k = max(scale, 1)
        let w = max(BitmapFont.cellWidth(for: text) * k, 1)
        let h = BitmapFont.height * k
        var out: [CGPoint] = []
        for c in cells {
            for dy in 0..<k {
                for dx in 0..<k {
                    let x = c.x * k + dx
                    let y = c.y * k + dy
                    // Cell centres, so glyphs sit inside the box rather than on its edge.
                    out.append(CGPoint(x: (CGFloat(x) + 0.5) / CGFloat(w),
                                       y: (CGFloat(y) + 0.5) / CGFloat(h)))
                }
            }
        }
        return out
    }

    static func circlePoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        return (0..<n).map { i in
            let a = 2 * .pi * CGFloat(i) / CGFloat(n) - .pi / 2
            return CGPoint(x: 0.5 + 0.5 * cos(a), y: 0.5 + 0.5 * sin(a))
        }
    }

    /// Classic heart curve, sampled by arc length so icons space evenly —
    /// naive uniform-t sampling bunches them at the cusp and the point.
    static func heartPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        return normalize(walk(count: n, samples: 2000) { u in
            let t = u * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return CGPoint(x: x, y: -y)   // flip: normalized y points down
        })
    }

    /// Archimedean spiral with radius ∝ √t, which keeps successive turns a
    /// constant distance apart instead of crowding at the centre.
    static func spiralPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        let turns: CGFloat = 2.5
        var out: [CGPoint] = []
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(max(n - 1, 1))
            let a = turns * 2 * .pi * t
            let r = 0.5 * sqrt(t)
            out.append(CGPoint(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a)))
        }
        return out
    }

    /// Grid laid out as close to the screen's proportions as possible.
    static func gridPoints(_ n: Int) -> [CGPoint] {
        guard n > 0 else { return [] }
        let cols = max(Int(ceil(sqrt(Double(n) * 1.6))), 1)
        let rows = max(Int(ceil(Double(n) / Double(cols))), 1)
        var out: [CGPoint] = []
        for i in 0..<n {
            let c = i % cols, r = i / cols
            out.append(CGPoint(x: (CGFloat(c) + 0.5) / CGFloat(cols),
                               y: (CGFloat(r) + 0.5) / CGFloat(rows)))
        }
        return out
    }

    /// Rescales an arbitrary point cloud into the unit box, preserving aspect
    /// ratio so shapes are not distorted.
    static func normalize(_ pts: [CGPoint]) -> [CGPoint] {
        guard let first = pts.first else { return [] }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let w = max(maxX - minX, 0.0001), h = max(maxY - minY, 0.0001)
        let s = 1 / max(w, h)
        // Centre the shorter axis.
        let offX = (1 - w * s) / 2, offY = (1 - h * s) / 2
        return pts.map {
            CGPoint(x: ($0.x - minX) * s + offX, y: ($0.y - minY) * s + offY)
        }
    }
}
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
import AppKit

/// Maps between Cocoa screen space and Finder's desktop coordinate space.
///
/// These two spaces differ in a way that is easy to get wrong and fails
/// *silently* — icons simply appear on the wrong monitor.
///
/// - Cocoa (`NSScreen.frame`): origin at the **main** screen's bottom-left,
///   y increasing **upward**. Screens left of main have negative x.
/// - Finder (`desktop position`): x is shared with Cocoa, but y increases
///   **downward** from the **main** screen's **top** edge.
///
/// So the transform is `finderY = mainScreen.maxY - cocoaY`, using the main
/// screen as the reference for *every* screen, not each screen's own frame.
///
/// Verified empirically against a three-display setup: writing y=1200 to a
/// screen whose Cocoa frame is y=37…1117 clamped to exactly 1080, which is
/// `1117 - 37` — confirming the main screen's top as the origin.
///
/// Do NOT use `bounds of window of desktop` to derive a target rect: it returns
/// the union of all displays (e.g. `-1920, 0, 3648, 1117`), so a layout fitted
/// to it spills across monitors.
struct ScreenMapper {
    /// Height of the main screen — the origin reference for the y flip.
    let mainMaxY: CGFloat
    /// The chosen display's usable area, in Finder coordinates.
    let finderRect: CGRect
    let displayName: String

    init(screen: NSScreen) {
        let main = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? screen
        self.mainMaxY = main.frame.maxY
        self.displayName = screen.localizedName

        // visibleFrame excludes the menu bar and Dock, so icons never land
        // underneath them.
        let v = screen.visibleFrame
        self.finderRect = CGRect(
            x: v.minX,
            y: mainMaxY - v.maxY,   // top edge in Finder space
            width: v.width,
            height: v.height
        )
    }

    func toFinder(_ cocoa: CGPoint) -> CGPoint {
        CGPoint(x: cocoa.x, y: mainMaxY - cocoa.y)
    }

    func toCocoa(_ finder: CGPoint) -> CGPoint {
        CGPoint(x: finder.x, y: mainMaxY - finder.y)
    }

    static var allScreens: [NSScreen] { NSScreen.screens }
}
import Foundation
let names = (1...46).map { "i\($0)" }
guard let main = NSScreen.screens.first(where: { $0.frame.origin == .zero }) else { exit(1) }
let m = ScreenMapper(screen: main)
var out: [String: Any] = [:]
let specs: [(String, Shape, String)] = [
    ("text", .text, "HI"), ("heart", .heart, ""), ("star", .star, ""),
    ("spiral", .spiral, ""), ("infinity", .infinity, ""), ("smiley", .smiley, ""),
    ("flower", .flower, ""), ("circle", .circle, ""), ("butterfly", .butterfly, ""),
    ("arrow", .arrow, ""), ("diamond", .diamond, ""), ("wave", .wave, ""),
    ("ring", .ring, ""), ("scatter", .scatter, ""), ("grid", .grid, "")
]
for (name, sh, txt) in specs {
    let plan = Placer.plan(shape: sh, text: txt, names: names, mapper: m)
    let pts = plan.previewShape
    guard !pts.isEmpty else { continue }
    let xs = pts.map(\.x), ys = pts.map(\.y)
    let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
    let w = max(maxX-minX, 1), h = max(maxY-minY, 1)
    let s = max(w, h)
    let offX = (s-w)/2, offY = (s-h)/2
    let norm = pts.map { [Double((($0.x-minX)+offX)/s), Double((($0.y-minY)+offY)/s)] }
    out[name] = ["points": norm, "count": pts.count]
}
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("exported \(out.count) shapes")
