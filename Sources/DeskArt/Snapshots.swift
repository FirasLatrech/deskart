import Foundation

/// A saved set of icon positions, so every arrangement is undoable.
struct Snapshot: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var date: Date
    /// Finder name -> position, in Finder coordinates.
    var positions: [String: CGPointCodable]

    var itemCount: Int { positions.count }
}

/// CGPoint is not Codable on macOS in a stable way across versions; this keeps
/// the on-disk format explicit.
struct CGPointCodable: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    init(_ p: CGPoint) { x = p.x; y = p.y }
    var point: CGPoint { CGPoint(x: x, y: y) }
}

@MainActor
final class SnapshotStore: ObservableObject {
    @Published private(set) var snapshots: [Snapshot] = []

    private let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeskArt", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("snapshots.json")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Snapshot].self, from: data)
        else { return }
        snapshots = decoded.sorted { $0.date > $1.date }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshots) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Captures the current Desktop. Called automatically before every apply,
    /// so a user can always get back to what they had.
    @discardableResult
    func capture(named name: String) async throws -> Snapshot {
        let items = try await Task.detached(priority: .userInitiated) {
            try FinderBridge.readItems()
        }.value
        var dict: [String: CGPointCodable] = [:]
        for i in items { dict[i.name] = CGPointCodable(i.position) }
        let snap = Snapshot(name: name, date: Date(), positions: dict)
        snapshots.insert(snap, at: 0)
        // Keep the list useful rather than unbounded.
        if snapshots.count > 40 { snapshots.removeLast(snapshots.count - 40) }
        persist()
        return snap
    }

    /// Restores a snapshot, skipping icons that no longer exist.
    /// Returns the number restored and the number that failed to land.
    ///
    /// Restore is verified for the same reason an apply is: this is the undo
    /// path, and a silently failed undo is worse than a failed arrange.
    @discardableResult
    func restore(_ snap: Snapshot) async throws -> (restored: Int, failed: Int) {
        let saved = snap.positions
        return try await Task.detached(priority: .userInitiated) {
            let present = Set(try FinderBridge.readItems().map(\.name))
            var placements: [String: CGPoint] = [:]
            for (name, p) in saved where present.contains(name) {
                placements[name] = p.point
            }
            try FinderBridge.apply(placements)
            let bad = try FinderBridge.verify(placements)
            return (placements.count, bad.count)
        }.value
    }

    func delete(_ snap: Snapshot) {
        snapshots.removeAll { $0.id == snap.id }
        persist()
    }
}
