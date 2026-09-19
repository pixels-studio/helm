import SwiftUI

struct WorkspaceView: View {
    @Environment(AppModel.self) private var model
    let session: Session

    var body: some View {
        Group {
            if let root = session.workspace.root { WorkspaceNodeView(node: root, session: session, path: []) }
            else { emptyState }
        }.padding(8).background(HelmColor.canvas)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("A workspace for this piece of work.").font(.system(size: 18, weight: .medium))
            Text("Every pane runs in the same session worktree.").foregroundStyle(HelmColor.secondary)
            HStack { Button("Claude") { model.addPane(.claude) }; Button("Codex") { model.addPane(.codex) }; Button("Terminal") { model.addPane(.terminal) }; Button("Browser") { model.addPane(.browser) }; Button("Diff") { model.addPane(.diff) } }
            Text(session.worktreeURL.path).font(HelmFont.mono).foregroundStyle(HelmColor.tertiary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(HelmColor.panel).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkspaceNodeView: View {
    @Environment(AppModel.self) private var model
    let node: WorkspaceNode
    let session: Session
    let path: [Bool]
    @State private var dragStart: Double?

    var body: some View {
        switch node {
        case .pane(let id): if let pane = model.pane(id) { PaneContainer(pane: pane, session: session) }
        case .split(let axis, let fraction, let first, let second):
            GeometryReader { geometry in
                if axis == .horizontal {
                    HStack(spacing: 0) { WorkspaceNodeView(node: first, session: session, path: path + [false]).frame(width: max(HelmDimension.minimumPaneWidth, geometry.size.width * fraction - 3)); divider(total: geometry.size.width); WorkspaceNodeView(node: second, session: session, path: path + [true]) }
                } else {
                    VStack(spacing: 0) { WorkspaceNodeView(node: first, session: session, path: path + [false]).frame(height: max(HelmDimension.minimumPaneHeight, geometry.size.height * fraction - 3)); divider(total: geometry.size.height); WorkspaceNodeView(node: second, session: session, path: path + [true]) }
                }
            }
        }
    }

    private func divider(total: CGFloat) -> some View {
        Rectangle().fill(HelmColor.canvas).frame(width: nodeAxis == .horizontal ? 8 : nil, height: nodeAxis == .vertical ? 8 : nil).contentShape(Rectangle()).gesture(DragGesture().onChanged { value in let start = dragStart ?? currentFraction; dragStart = start; let delta = nodeAxis == .horizontal ? value.translation.width : value.translation.height; model.updateSplit(path: path, fraction: start + delta / max(1, total)) }.onEnded { _ in dragStart = nil })
    }
    private var nodeAxis: SplitAxis { if case .split(let axis, _, _, _) = node { axis } else { .horizontal } }
    private var currentFraction: Double { if case .split(_, let fraction, _, _) = node { fraction } else { 0.5 } }
}

private struct PaneContainer: View {
    let pane: Pane; let session: Session
    var body: some View {
        VStack(spacing: 0) { PaneHeader(pane: pane, session: session); paneContent }
            .background(HelmColor.panel).clipShape(RoundedRectangle(cornerRadius: HelmRadius.pane))
            .frame(minWidth: HelmDimension.minimumPaneWidth, minHeight: HelmDimension.minimumPaneHeight)
    }
    @ViewBuilder private var paneContent: some View {
        switch pane.kind {
        case .claude, .codex, .terminal: TerminalPaneView(pane: pane, session: session)
        case .diff, .git: DiffPaneView(session: session)
        case .file: FilePaneView(pane: pane, session: session)
        case .browser: BrowserPaneView(pane: pane)
        }
    }
}
