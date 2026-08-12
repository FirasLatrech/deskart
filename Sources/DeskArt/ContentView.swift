import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var showSnapshots = false
    @State private var pendingDelete: Snapshot?

    var body: some View {
        let plan = model.plan

        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            if model.items.isEmpty {
                emptyState
            } else {
                shapeControls
                preview(plan)
                notes(plan)
                actions(plan)
                if showSnapshots { snapshotList }
            }

            statusLine
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { model.refresh() }
        // Destructive and irreversible: a snapshot is the only way back to a
        // previous arrangement, so deleting one asks first.
        .alert(
            "Delete this snapshot?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { snap in
            Button("Delete", role: .destructive) {
                model.snapshots.delete(snap)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { snap in
            Text("“\(snap.name)” records \(snap.itemCount) icon positions. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundStyle(.tint)
            Text("DeskArt").font(.headline)

            if !model.items.isEmpty {
                Text("\(model.items.count) icons")
                    .font(.caption.monospacedDigit())   // digits shouldn't jitter
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .help("Icons on the Desktop")
            }

            Spacer()

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.busy)
            .help("Re-read the Desktop")
            .accessibilityLabel("Reload Desktop icons")
        }
    }

    // MARK: - Empty state

    /// An empty state needs one clear next action, not just a statement of
    /// the problem.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No icons on the Desktop", systemImage: "square.dashed")
                .font(.callout.weight(.medium))
            Text("DeskArt arranges the icons already on your Desktop. Add some files or folders, then reload.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                model.refresh()
            } label: {
                Label("Reload Desktop", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    // MARK: - Controls

    /// Labels are laid out in a `Grid` so "Shape" and "Display" share one
    /// column and their controls line up — as separate `Picker` labels they
    /// each sized to their own text and the fields stepped raggedly.
    @ViewBuilder
    private var shapeControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Text("Shape")
                    .font(.callout)
                    .gridColumnAlignment(.leading)
                HStack(spacing: 6) {
                    // Grouped by family — a flat list of fifteen is hard to scan.
                    Picker("", selection: $model.shape) {
                        ForEach(Shape.Family.allCases, id: \.self) { fam in
                            Section(fam.rawValue.capitalized) {
                                ForEach(Shape.allCases.filter { $0.family == fam }) { s in
                                    Label(s.label, systemImage: s.symbol).tag(s)
                                }
                            }
                        }
                    }
                    .labelsHidden()

                    Button {
                        model.surpriseMe()
                    } label: {
                        Image(systemName: "dice")
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.busy)
                    .help("Surprise me — pick a random shape")
                    .accessibilityLabel("Pick a random shape")
                }
            }

            if model.shape.needsText {
                GridRow {
                    Text("Text").font(.callout)
                    TextField("e.g. HI", text: $model.text)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Text to render as icons")
                }
            }

            // Only worth showing when there is a choice to make.
            if model.screens.count > 1 {
                GridRow {
                    Text("Display").font(.callout)
                    Picker("", selection: $model.screenIndex) {
                        ForEach(Array(model.screens.enumerated()), id: \.offset) { i, s in
                            Text(displayLabel(s)).tag(i)
                        }
                    }
                    .labelsHidden()
                }
            }
        }
    }

    private func displayLabel(_ s: NSScreen) -> String {
        let main = s.frame.origin == .zero ? " (Main)" : ""
        return "\(s.localizedName)\(main)"
    }

    // MARK: - Preview

    private func preview(_ plan: Placer.Plan) -> some View {
        VStack(spacing: 6) {
            PreviewCanvas(plan: plan, mapper: model.mapper)
                .frame(height: 132)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12))
                )
                .accessibilityLabel(
                    plan.shapeCount > 0
                    ? "Preview: \(plan.shapeCount) icons forming a \(model.shape.label)"
                        + (plan.parkedCount > 0 ? ", \(plan.parkedCount) parked in the corner" : "")
                    : "Preview: nothing to show"
                )

            // Caption sits *below* the canvas rather than floating inside it:
            // as an overlay it landed on top of the very parked dots it was
            // labelling. It doubles as the count readout, so the same numbers
            // are not also repeated under the buttons.
            if plan.shapeCount > 0 {
                HStack(spacing: 10) {
                    legendItem(.cyan, "\(plan.shapeCount) in \(model.shape.label.lowercased())")
                    if plan.parkedCount > 0 {
                        legendItem(.gray.opacity(0.6), "\(plan.parkedCount) parked")
                    }
                    Spacer(minLength: 0)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Notes

    /// Warnings and informational notes are visually distinct: showing "25
    /// icons parked" with the same orange alarm as "your text is too wide"
    /// teaches the user to ignore both.
    @ViewBuilder
    private func notes(_ plan: Placer.Plan) -> some View {
        // The parked count is already stated in the preview caption, so its
        // note would be the same fact a third time on screen.
        let shown = plan.notes.filter { !$0.text.contains("parked in the corner") }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(shown, id: \.self) { n in
                    Label {
                        Text(n.text)
                    } icon: {
                        Image(systemName: n.level == .warning
                              ? "exclamationmark.triangle.fill" : "info.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(n.level == .warning ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ plan: Placer.Plan) -> some View {
        HStack(spacing: 8) {
            Button {
                model.apply()
            } label: {
                HStack(spacing: 5) {
                    if model.busy {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    // Applying takes a couple of seconds; without this the
                    // window looks frozen.
                    Text(model.busy ? "Arranging…" : "Arrange")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(plan.placements.isEmpty || model.busy)
            .help("Move Desktop icons into this shape")

            // Secondary actions read as borderless glyphs so the single accent
            // stays on Arrange — as bordered buttons they carried nearly the
            // same visual weight as the primary action.
            Button {
                model.captureManual()
            } label: {
                Image(systemName: "camera")
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(model.busy)
            .help("Save a snapshot of the current positions")
            .accessibilityLabel("Save snapshot")

            Button {
                showSnapshots.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
                    .background(
                        // Toggle state needs to be visible; otherwise there's
                        // no way to tell the panel is open.
                        showSnapshots ? Color.secondary.opacity(0.2) : .clear,
                        in: RoundedRectangle(cornerRadius: 5)
                    )
            }
            .buttonStyle(.borderless)
            .help(showSnapshots ? "Hide snapshots" : "Show snapshots")
            .accessibilityLabel(showSnapshots ? "Hide snapshots" : "Show snapshots")
        }

        // Undo is the reassurance that makes Arrange safe to press, so it sits
        // next to it rather than behind the history panel.
        HStack(spacing: 8) {
            if let last = model.snapshots.snapshots.first {
                Button {
                    model.restore(last)
                } label: {
                    Label("Undo — \(last.name)", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .controlSize(.small)
                .disabled(model.busy)
                .help("Restore the most recent snapshot")
            }

            Spacer()
        }
    }

    // MARK: - Snapshots

    @ViewBuilder
    private var snapshotList: some View {
        Divider()
        HStack {
            Text("Snapshots").font(.caption.bold()).foregroundStyle(.secondary)
            Spacer()
            if !model.snapshots.snapshots.isEmpty {
                Text("\(model.snapshots.snapshots.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }

        if model.snapshots.snapshots.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No snapshots yet.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    model.captureManual()
                } label: {
                    Label("Save the current layout", systemImage: "camera")
                }
                .controlSize(.small)
                .disabled(model.busy)
            }
            .padding(.vertical, 2)
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(model.snapshots.snapshots) { s in
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("\(s.itemCount) icons · \(s.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Button("Restore") { model.restore(s) }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .disabled(model.busy)
                                .accessibilityLabel("Restore snapshot \(s.name)")
                            Button {
                                pendingDelete = s
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.busy)
                            .help("Delete this snapshot")
                            .accessibilityLabel("Delete snapshot \(s.name)")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusLine: some View {
        if !model.status.isEmpty {
            Label {
                Text(model.status)
            } icon: {
                // A checkmark only where something was actually verified —
                // putting one next to a neutral icon count would claim a
                // confirmation that never happened.
                Image(systemName: model.isError
                      ? "exclamationmark.circle.fill"
                      : (model.status.contains("verified") ? "checkmark.circle" : "info.circle"))
            }
            .font(.caption)
            .foregroundStyle(model.isError ? .red : .secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)   // errors are worth copying
        }
    }
}

/// Draws the planned layout at the target display's aspect ratio, so what the
/// user sees is what lands on the Desktop.
struct PreviewCanvas: View {
    let plan: Placer.Plan
    let mapper: ScreenMapper?

    var body: some View {
        Canvas { ctx, size in
            guard let mapper else { return }
            let rect = mapper.finderRect
            guard rect.width > 0, rect.height > 0 else { return }

            // Inset so dots at the screen edge are not clipped by the canvas
            // bounds — icons sit half a footprint from the edge in reality.
            let inset: CGFloat = 8
            let avail = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
            let scale = min(avail.width / rect.width, avail.height / rect.height)
            let w = rect.width * scale, h = rect.height * scale
            let offX = (size.width - w) / 2, offY = (size.height - h) / 2

            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: offX + (p.x - rect.minX) * scale,
                        y: offY + (p.y - rect.minY) * scale)
            }

            // The screen itself, so the shape is read in the context of the
            // display it will land on rather than floating in a void.
            ctx.stroke(
                Path(roundedRect: CGRect(x: offX, y: offY, width: w, height: h), cornerRadius: 3),
                with: .color(.white.opacity(0.09)),
                lineWidth: 1
            )

            // Dots sized to the true 68pt footprint, so crowding shows up here
            // rather than as a surprise on the Desktop. Floored at 2pt: below
            // that the shape stops reading at all.
            let r = max(Placer.minSpacing * scale / 2.6, 2)

            for p in plan.previewParked {
                let c = map(p)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(0.22))
                )
            }
            // Shape drawn last so it is never hidden behind parked dots.
            for p in plan.previewShape {
                let c = map(p)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                    with: .color(.cyan)
                )
            }
        }
    }
}
