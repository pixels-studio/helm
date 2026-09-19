import SwiftUI

struct PaneHeader: View {
    @Environment(AppModel.self) private var model
    let pane: Pane
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            if pane.kind == .claude { HelmIcon(name: "claude") }
            else if pane.kind == .diff { HelmIcon(name: "diff") }
            else { Image(systemName: pane.kind.symbol).frame(width: 20, height: 20).foregroundStyle(pane.kind == .codex ? HelmColor.orange : HelmColor.primary) }
            Text(pane.title).font(HelmFont.ui).lineLimit(1)
            BranchChip(branch: session.branch ?? "Folder")
            Spacer()
            Menu { ForEach(PaneKind.allCases, id: \.self) { kind in Button("Add \(kind.title)") { model.addPane(kind) } }; Divider(); Button("Split Below") { model.addPane(.terminal, axis: .vertical) }; Button("Close Pane", role: .destructive) { model.closePane(pane.id) } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 20)
        }.padding(.horizontal, 16).frame(height: HelmDimension.headerHeight).contentShape(Rectangle()).onTapGesture { model.focusPane(pane.id) }
    }
}
