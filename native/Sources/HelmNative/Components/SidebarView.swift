import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var hoveredSession: UUID?

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Color.clear.frame(height: 56)
            HStack(spacing: 8) { HelmIcon(name: "search"); TextField("Search", text: $model.searchText).textFieldStyle(.plain) }
                .foregroundStyle(HelmColor.tertiary).padding(.horizontal, 20).frame(height: 36)
            Button(action: model.addProject) { HStack(spacing: 8) { HelmIcon(name: "add"); Text("New Project"); Spacer() }.padding(.horizontal, 20).frame(height: 36) }
                .buttonStyle(.plain).foregroundStyle(HelmColor.tertiary)
            ScrollView {
                LazyVStack(spacing: 40) {
                    ForEach(model.state.projects) { project in projectSection(project) }
                }.padding(.horizontal, 12).padding(.top, 44)
            }
            Spacer(minLength: 8)
            footerRow("settings", "Settings")
            footerRow("help", "Help")
        }
        .frame(width: HelmDimension.sidebarWidth)
        .background(HelmColor.canvas)
    }

    @ViewBuilder private func projectSection(_ project: Project) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle").foregroundStyle(project.id == model.state.selectedProjectID ? .red : HelmColor.secondary).frame(width: 20)
                Button(project.name) { model.selectProject(project.id) }.buttonStyle(.plain).font(HelmFont.label).foregroundStyle(HelmColor.secondary).lineLimit(1)
                Spacer(); Menu { Button("New Session") { model.selectProject(project.id); model.isCreatingSession = true }; Button("Remove from Helm", role: .destructive) { model.removeProject(project.id) } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 20)
                Button { model.selectProject(project.id); model.isCreatingSession = true } label: { Image(systemName: "plus") }.buttonStyle(.plain).frame(width: 20)
            }.frame(height: 36).padding(.horizontal, 8)
            ForEach(model.sessions(for: project)) { session in
                Button { model.selectSession(session.id) } label: {
                    HStack(spacing: 8) { Circle().fill(session.id == model.state.selectedSessionID ? Color.green : Color.white.opacity(0.2)).frame(width: 8, height: 8); Text(session.title).lineLimit(1); Spacer(); if hoveredSession == session.id { Image(systemName: "ellipsis") } }
                        .padding(.horizontal, 8).frame(height: 36).contentShape(Rectangle())
                }.buttonStyle(HelmHoverButtonStyle(selected: session.id == model.state.selectedSessionID)).onHover { hoveredSession = $0 ? session.id : nil }.contextMenu { Button("Remove Session", role: .destructive) { Task { await model.removeSession(session.id) } } }
            }
        }
    }

    private func footerRow(_ icon: String, _ title: String) -> some View {
        Button {} label: { HStack(spacing: 8) { HelmIcon(name: icon); Text(title); Spacer() }.padding(.horizontal, 8).frame(height: 40) }
            .buttonStyle(.plain).foregroundStyle(HelmColor.tertiary).padding(.horizontal, 12)
    }
}
