import SwiftUI

struct DiffPaneView: View {
    @Environment(AppModel.self) private var model
    let session: Session
    @State private var selected: String?
    @State private var diff = ""

    private var status: GitStatus { model.gitStatuses[session.id] ?? GitStatus(isRepository: false, branch: "", changes: []) }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if status.changes.isEmpty { ContentUnavailableView(status.isRepository ? "Working Tree Clean" : "Not a Git Repository", systemImage: status.isRepository ? "checkmark.circle" : "folder") }
                ForEach(status.changes) { change in
                    Button { selected = change.path; Task { diff = await model.diff(for: change.path) } } label: {
                        HStack(spacing: 12) { HelmIcon(name: "file", size: 24); Text(change.path).font(HelmFont.file).lineLimit(1); Spacer(); Text(change.statusLabel).foregroundStyle(HelmColor.green).font(HelmFont.file) }
                            .padding(.horizontal, 16).frame(height: 56).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if selected == change.path { UnifiedDiffView(diff: diff).padding(.horizontal, 16).padding(.bottom, 16) }
                }
            }
        }.task { await model.refreshGit() }
    }
}

private struct UnifiedDiffView: View {
    let diff: String
    var body: some View {
        ScrollView(.horizontal) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diff.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 16) {
                        Text("\(index + 1)").frame(width: 30, alignment: .trailing).foregroundStyle(line.first == "+" ? HelmColor.green : HelmColor.secondary)
                        Text(String(line)).foregroundStyle(color(for: line.first))
                    }.font(HelmFont.mono).frame(minHeight: 21)
                }
            }.padding(12)
        }.background(HelmColor.diffBackground).overlay(RoundedRectangle(cornerRadius: 8).stroke(HelmColor.diffBorder)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func color(for prefix: Character?) -> Color { prefix == "+" ? HelmColor.green : prefix == "-" ? HelmColor.orange : .white.opacity(0.9) }
}
