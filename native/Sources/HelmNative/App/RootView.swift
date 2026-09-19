import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            if let session = model.selectedSession { WorkspaceView(session: session) }
            else { WelcomeView() }
        }
        .frame(minWidth: HelmDimension.minimumWindowWidth, minHeight: HelmDimension.minimumWindowHeight)
        .background(HelmColor.canvas).foregroundStyle(HelmColor.primary).font(HelmFont.ui)
        .sheet(isPresented: Bindable(model).isCreatingSession) { NewSessionView() }
        .alert("Helm", isPresented: Binding(get: { !model.errors.isEmpty }, set: { if !$0 { model.dismissError() } })) { Button("OK") { model.dismissError() } } message: { Text(model.errors.first ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.terminalRegistry.stopAll() }
    }
}

private struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 16) {
            Text("HELM").tracking(4).foregroundStyle(HelmColor.tertiary)
            Text("Your agents. One workspace.").font(.system(size: 24, weight: .medium))
            Text("Add a local project, create a session, and get to work.").foregroundStyle(HelmColor.secondary)
            Button("Add Local Project", action: model.addProject)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(HelmColor.panel).clipShape(RoundedRectangle(cornerRadius: 8)).padding(8)
    }
}
