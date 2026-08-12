import AppKit
import CoreGraphics
import Foundation

/// One Desktop icon as Finder reports it.
///
/// `name` is Finder's name, which is NOT always the filesystem name: `.app`
/// bundles report without their extension (and Finder considers them folders).
/// Always round-trip through this name — never through FileManager's.
struct DesktopItem: Equatable {
    var name: String
    /// Position in Finder's desktop coordinate space (see `ScreenMapper`).
    var position: CGPoint
}

enum FinderError: LocalizedError {
    case scriptFailed(String)
    case malformedResponse(String)
    case arrangementEnabled(String)
    /// Automation access to Finder is missing. Distinct from `scriptFailed`
    /// because it is the one error the user can actually fix, and the fix is
    /// not obvious — see `FinderBridge.openAutomationSettings`.
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return """
                DeskArt needs permission to control Finder. Finder is the only \
                way macOS exposes Desktop icon positions.
                """
        case .scriptFailed(let msg):
            return "Finder rejected the request: \(msg)"
        case .malformedResponse(let msg):
            return "Could not understand Finder's reply: \(msg)"
        case .arrangementEnabled(let mode):
            return """
                The Desktop is set to “\(mode)”, so Finder re-sorts icons the moment \
                they are moved. Right-click the Desktop → Sort By → None (and turn off \
                Use Stacks) before arranging.
                """
        }
    }
}

/// All Finder communication. Every operation is a *single* Apple Event round
/// trip — one `set desktop position` per icon would cost seconds across a full
/// Desktop.
enum FinderBridge {

    /// Separator for the read protocol. Chosen because it cannot occur in a
    /// macOS filename; a plain comma-joined list breaks on names containing
    /// commas, which is silent and produces garbage offsets.
    private static let sep = "|||"

    // MARK: - Script execution

    /// Serializes every Apple Event. Verified that `NSAppleScript` executes
    /// correctly off the main thread, but overlapping scripts would still
    /// interleave a read with a write — e.g. a menu-open refresh landing in the
    /// middle of an apply, which would read half-moved positions and report a
    /// false verify failure. One queue makes the ordering explicit.
    private static let queue = DispatchQueue(label: "com.horizon.deskart.finder")

    @discardableResult
    static func run(_ source: String) throws -> String {
        try queue.sync {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw FinderError.scriptFailed("could not compile script")
            }
            let result = script.executeAndReturnError(&error)
            if let error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                let msg = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
                // -1743 is "user has not been asked / has declined"; -600 means
                // Finder was not reachable, which TCC also reports when access
                // is withheld. Both are the same problem for the user.
                if code == Int(errAEEventNotPermitted) || code == Int(procNotFound) {
                    throw FinderError.notAuthorized
                }
                throw FinderError.scriptFailed(msg)
            }
            return result.stringValue ?? ""
        }
    }

    // MARK: - Authorization

    /// Finder's bundle identifier, as an Apple Event target.
    private static let finderID = "com.apple.finder"

    /// Asks macOS for Automation access to Finder, showing the system consent
    /// prompt if the user has not been asked yet.
    ///
    /// Called up front so the prompt appears as a deliberate request rather
    /// than as a red failure string after an action the user already started.
    /// Blocking — the system dialog is modal — so keep it off the main actor.
    ///
    /// Returns `true` if Apple Events may now be sent to Finder.
    @discardableResult
    static func requestAuthorization(askIfNeeded: Bool = true) -> Bool {
        var target = AEAddressDesc()
        guard finderID.withCString({ cString -> OSErr in
            AECreateDesc(
                typeApplicationBundleID,
                cString,
                strlen(cString),
                &target
            )
        }) == noErr else { return false }
        defer { AEDisposeDesc(&target) }

        let status = AEDeterminePermissionToAutomateTarget(
            &target,
            typeWildCard,
            typeWildCard,
            askIfNeeded
        )
        return status == noErr
    }

    /// Whether access has already been granted, without ever prompting.
    static var isAuthorized: Bool { requestAuthorization(askIfNeeded: false) }

    /// Opens System Settings → Privacy & Security → Automation.
    ///
    /// Once a user has declined, macOS will never prompt again, so this pane is
    /// the only way back — an error message alone would leave them stuck.
    @MainActor
    static func openAutomationSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        )!
        NSWorkspace.shared.open(url)
    }

    /// Escapes a name for embedding in an AppleScript string literal.
    /// Without this, a folder named `say "hi"` or containing a backslash
    /// produces a script that fails to compile — or worse, one that compiles
    /// into something unintended.
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Arrangement guard

    /// Reads the Desktop's icon arrangement. Anything other than "not arranged"
    /// means Finder will immediately undo our writes, so we refuse to apply.
    static func arrangement() throws -> String {
        let out = try run("""
            tell application "Finder"
                return (arrangement of icon view options of window of desktop) as text
            end tell
            """)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func assertArrangementAllowsPlacement() throws {
        let mode = try arrangement()
        // Finder spells this "not arranged"; every other value snaps or sorts.
        guard mode.lowercased().contains("not arranged") else {
            throw FinderError.arrangementEnabled(mode)
        }
    }

    // MARK: - Read

    /// Reads every Desktop item's Finder name and position in one round trip.
    ///
    /// Note the index-based `repeat`: `repeat with t in (every item of desktop)`
    /// yields a reference that will not coerce, failing with -1700.
    static func readItems() throws -> [DesktopItem] {
        let source = """
            tell application "Finder"
                set theItems to every item of desktop
                set out to ""
                repeat with i from 1 to count of theItems
                    set t to item i of theItems
                    set p to desktop position of t
                    set out to out & (name of t) & "\(sep)" & ((item 1 of p) as integer) & "\(sep)" & ((item 2 of p) as integer) & linefeed
                end repeat
                return out
            end tell
            """
        let raw = try run(source)
        return try parse(raw)
    }

    static func parse(_ raw: String) throws -> [DesktopItem] {
        var items: [DesktopItem] = []
        for line in raw.split(whereSeparator: \.isNewline) {
            let parts = line.components(separatedBy: sep)
            guard parts.count == 3,
                  let x = Double(parts[1].trimmingCharacters(in: .whitespaces)),
                  let y = Double(parts[2].trimmingCharacters(in: .whitespaces))
            else {
                throw FinderError.malformedResponse(String(line))
            }
            items.append(DesktopItem(name: parts[0], position: CGPoint(x: x, y: y)))
        }
        return items
    }

    // MARK: - Write

    /// Applies all placements in a single Apple Event.
    ///
    /// Deliberately NOT wrapped in a per-item `try` block: a swallowed failure
    /// makes a no-op run look successful. Failures propagate, and `verify`
    /// independently confirms what actually landed.
    static func apply(_ placements: [String: CGPoint]) throws {
        guard !placements.isEmpty else { return }
        var lines: [String] = []
        for (name, p) in placements {
            lines.append(
                "set desktop position of item \"\(escape(name))\" of desktop to {\(Int(p.x.rounded())), \(Int(p.y.rounded()))}"
            )
        }
        let source = """
            tell application "Finder"
            \(lines.joined(separator: "\n"))
            end tell
            """
        try run(source)
    }

    // MARK: - Verify

    struct Mismatch {
        var name: String
        var expected: CGPoint
        var actual: CGPoint?
    }

    /// Reads positions back and compares against what we asked for.
    ///
    /// Tolerance is required, not defensive padding: Finder rounds, and any
    /// residual grid snapping shifts a position by a few points. Exact equality
    /// reports false failures.
    static func verify(_ placements: [String: CGPoint], tolerance: CGFloat = 10) throws -> [Mismatch] {
        let actual = Dictionary(
            try readItems().map { ($0.name, $0.position) },
            uniquingKeysWith: { a, _ in a }
        )
        var bad: [Mismatch] = []
        for (name, want) in placements {
            guard let got = actual[name] else {
                bad.append(Mismatch(name: name, expected: want, actual: nil))
                continue
            }
            if abs(got.x - want.x) > tolerance || abs(got.y - want.y) > tolerance {
                bad.append(Mismatch(name: name, expected: want, actual: got))
            }
        }
        return bad
    }
}
