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
