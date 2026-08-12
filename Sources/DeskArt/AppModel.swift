import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var shape: Shape = .text
    @Published var text: String = "HI"
    @Published var screenIndex: Int = 0
    @Published var items: [DesktopItem] = []
    @Published var status: String = ""
    @Published var isError: Bool = false
    @Published var busy: Bool = false
    /// Drives the "Open System Settings" recovery button. Set whenever a Finder
    /// call fails for lack of Automation access, since that is the one failure
    /// the user can fix and macOS will not re-prompt for.
    @Published var needsAuthorization: Bool = false

    let snapshots = SnapshotStore()

    var screens: [NSScreen] { NSScreen.screens }

    var mapper: ScreenMapper? {
        guard screens.indices.contains(screenIndex) else { return nil }
        return ScreenMapper(screen: screens[screenIndex])
    }

    /// The live plan for the current settings, recomputed on demand.
    var plan: Placer.Plan {
        guard let mapper else { return Placer.Plan() }
        return Placer.plan(shape: shape, text: text, names: items.map(\.name), mapper: mapper)
    }

    /// Picks a random shape, avoiding an immediate repeat so the button always
    /// visibly does something.
    func surpriseMe() {
        let pool = Shape.randomizable.filter { $0 != shape }
        shape = pool.randomElement() ?? .star
        isError = false
        status = "Surprise: \(shape.label)."
    }

    /// Records a failure, flagging the authorization case so the UI can offer
    /// the System Settings route instead of a dead-end error string.
    private func report(_ error: Error) {
        isError = true
        status = error.localizedDescription
        if case FinderError.notAuthorized = error { needsAuthorization = true }
    }

    /// Triggers the macOS consent prompt for controlling Finder.
    ///
    /// Runs on first launch so the user is asked at a natural moment. If they
    /// have already answered, macOS does not prompt again and this is a no-op
    /// beyond refreshing `needsAuthorization`.
    func requestAuthorizationThenRefresh() {
        Task {
            let granted = await Self.offMainValue { FinderBridge.requestAuthorization() }
            needsAuthorization = !granted
            if granted {
                refresh()
            } else {
                isError = true
                status = FinderError.notAuthorized.localizedDescription
            }
        }
    }

    @MainActor
    func openAutomationSettings() { FinderBridge.openAutomationSettings() }

    /// Reads the Desktop off the main actor: this runs on every menu open, and
    /// a slow Finder would otherwise freeze the popover as it appears.
    func refresh() {
        guard !busy else { return }
        Task {
            do {
                items = try await Self.offMain { try FinderBridge.readItems() }
                isError = false
                needsAuthorization = false
                // The header badge already shows the count, so a status line
                // repeating it is noise. Stay quiet until something happens.
                status = ""
            } catch {
                report(error)
            }
        }
    }

    /// Snapshot → apply → read back and verify. The verify step is not
    /// optional: a run that silently moved nothing otherwise looks identical
    /// to a successful one.
    ///
    /// A full apply is several Apple Event round trips and takes a couple of
    /// seconds. Running it inline on the main actor would freeze the menu and
    /// never let `busy` render, so the Finder work happens off-actor and only
    /// the resulting state lands back on the main actor.
    func apply() {
        guard !busy else { return }

        let plan = self.plan
        guard !plan.placements.isEmpty else {
            isError = true
            status = plan.warnings.first ?? "Nothing to place."
            return
        }
        let snapName = autoSnapshotName()
        let displayName = mapper?.displayName ?? "display"

        busy = true
        status = "Arranging \(plan.placements.count) icons…"
        isError = false

        Task {
            do {
                // Guard, snapshot, apply, verify — all off the main actor.
                try await Self.offMain { try FinderBridge.assertArrangementAllowsPlacement() }
                try await snapshots.capture(named: snapName)
                try await Self.offMain { try FinderBridge.apply(plan.placements) }
                let bad = try await Self.offMain { try FinderBridge.verify(plan.placements) }

                if bad.isEmpty {
                    isError = false
                    status = "Placed \(plan.shapeCount) icon\(plan.shapeCount == 1 ? "" : "s")"
                        + (plan.parkedCount > 0 ? " (+\(plan.parkedCount) parked)" : "")
                        + " on \(displayName) — verified."
                } else {
                    isError = true
                    let missing = bad.filter { $0.actual == nil }.count
                    status = "\(bad.count) of \(plan.placements.count) icons did not land"
                        + (missing > 0 ? " (\(missing) not found by name)" : "")
                        + ". Check that Desktop sorting is off."
                }
                await refreshQuiet()
            } catch {
                report(error)
            }
            busy = false
        }
    }

    func restore(_ snap: Snapshot) {
        guard !busy else { return }
        busy = true
        status = "Restoring “\(snap.name)”…"
        isError = false

        Task {
            do {
                let (n, failed) = try await snapshots.restore(snap)
                isError = failed > 0
                status = failed == 0
                    ? "Restored \(n) icon\(n == 1 ? "" : "s") from “\(snap.name)” — verified."
                    : "Restored \(n - failed) of \(n) icons; \(failed) did not land. Check that Desktop sorting is off."
                await refreshQuiet()
            } catch {
                report(error)
            }
            busy = false
        }
    }

    /// Runs blocking Finder I/O off the main actor.
    private static func offMain<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated) { try work() }.value
    }

    /// Non-throwing variant, for the authorization check. Kept separate so the
    /// modal consent dialog never blocks the main actor.
    private static func offMainValue<T: Sendable>(
        _ work: @escaping @Sendable () -> T
    ) async -> T {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    func captureManual() {
        guard !busy else { return }
        busy = true
        status = "Saving snapshot…"
        isError = false
        Task {
            do {
                let s = try await snapshots.capture(named: manualSnapshotName())
                isError = false
                status = "Saved snapshot of \(s.itemCount) icons."
            } catch {
                report(error)
            }
            busy = false
        }
    }

    /// Re-reads positions without touching `status`, so it never overwrites the
    /// result message an apply just wrote.
    private func refreshQuiet() async {
        if let fresh = try? await Self.offMain({ try FinderBridge.readItems() }) {
            items = fresh
        }
    }

    private func autoSnapshotName() -> String {
        let label = shape == .text ? "\(shape.label) “\(text)”" : shape.label
        return "Before \(label)"
    }

    private func manualSnapshotName() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return "Manual — \(f.string(from: Date()))"
    }
}
