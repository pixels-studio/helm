import AppKit
import SwiftUI

@main
struct HelmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup { RootView().environment(model).preferredColorScheme(.dark) }
            .windowStyle(.automatic)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Add Project…") { model.addProject() }.keyboardShortcut("o")
                    Button("New Session…") { model.isCreatingSession = model.selectedProject != nil }.keyboardShortcut("n")
                }
                CommandMenu("Workspace") {
                    Button("Add Claude Pane") { model.addPane(.claude) }.keyboardShortcut("1", modifiers: [.command, .shift])
                    Button("Add Codex Pane") { model.addPane(.codex) }.keyboardShortcut("2", modifiers: [.command, .shift])
                    Button("Add Terminal Pane") { model.addPane(.terminal) }.keyboardShortcut("3", modifiers: [.command, .shift])
                    Button("Add Browser Pane") { model.addPane(.browser) }.keyboardShortcut("4", modifiers: [.command, .shift])
                    Button("Add Diff Pane") { model.addPane(.diff) }.keyboardShortcut("5", modifiers: [.command, .shift])
                }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }
            window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView); window.isMovableByWindowBackground = true
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
            window.backgroundColor = NSColor(calibratedWhite: 17/255, alpha: 1)
            window.minSize = NSSize(width: HelmDimension.minimumWindowWidth, height: HelmDimension.minimumWindowHeight)
            window.setFrame(NSRect(x: window.frame.minX, y: window.frame.minY, width: 1504, height: 896), display: true)
        }
    }
}
