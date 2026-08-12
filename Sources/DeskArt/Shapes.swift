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
