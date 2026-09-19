import SwiftUI

struct NewSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var base = ""
    @State private var useWorktree = true
    @State private var branches: [String] = []
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Session").font(HelmFont.label)
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Name").foregroundStyle(HelmColor.secondary)
                TextField("Implement Meeting Link", text: $title).textFieldStyle(.plain).padding(.horizontal, 12).frame(height: 40).background(Color.white.opacity(0.04)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1)))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Branch").foregroundStyle(HelmColor.secondary)
                Picker("Target Branch", selection: $base) { ForEach(branches, id: \.self) { Text($0).tag($0) } }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle("Use worktree", isOn: $useWorktree).toggleStyle(.switch)
            Button { creating = true; Task { if await model.createSession(title: title, base: base, useWorktree: useWorktree) { dismiss() }; creating = false } } label: { Text(creating ? "Creating…" : "Create").frame(maxWidth: .infinity).frame(height: 40).background(Color.white).foregroundStyle(.black).clipShape(Capsule()) }
                .buttonStyle(.plain).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || creating || (useWorktree && base.isEmpty))
        }.padding(28).frame(width: 360).background(HelmColor.panel).task { branches = await model.branches(); base = branches.first(where: { $0 == "main" }) ?? branches.first ?? ""; useWorktree = !branches.isEmpty }
    }
}
