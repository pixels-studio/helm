import AppKit
import SwiftTerm
import SwiftUI

@MainActor
final class TerminalRegistry {
    private var terminals: [UUID: HelmTerminalView] = [:]

    func terminal(for pane: Pane, session: Session, fontSize: CGFloat) -> HelmTerminalView {
        if let existing = terminals[pane.id] { return existing }
        let view = HelmTerminalView(frame: .zero)
        try? view.setUseMetal(false)
        view.nativeBackgroundColor = NSColor(calibratedWhite: 26/255, alpha: 1)
        view.nativeForegroundColor = NSColor(calibratedWhite: 0.9, alpha: 1)
        view.layer?.backgroundColor = view.nativeBackgroundColor.cgColor
        view.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        view.getTerminal().setCursorStyle(.steadyBlock)
        view.start(kind: pane.kind, cwd: session.worktreeURL)
        terminals[pane.id] = view
        return view
    }

    func stop(paneID: UUID) { terminals.removeValue(forKey: paneID)?.terminate() }
    func stop(sessionID: UUID) {
        let ids = terminals.filter { $0.value.sessionID == sessionID }.map(\.key)
        ids.forEach(stop(paneID:))
    }
    func stopAll() { terminals.values.forEach { $0.terminate() }; terminals.removeAll() }
}

final class HelmTerminalView: LocalProcessTerminalView {
    var sessionID: UUID?
    private(set) var capturedOutput = ""

    func start(kind: PaneKind, cwd: URL) {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let extraPaths = [FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin").path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let path = ([ProcessInfo.processInfo.environment["PATH"]].compactMap { $0 } + extraPaths).joined(separator: ":")
        var environmentMap = ProcessInfo.processInfo.environment
        environmentMap["TERM"] = "xterm-256color"
        environmentMap["COLORTERM"] = "truecolor"
        environmentMap["PATH"] = path
        let environment = environmentMap.map { "\($0.key)=\($0.value)" }
        switch kind {
        case .claude: startProcess(executable: "/usr/bin/env", args: ["claude"], environment: environment, execName: "claude", currentDirectory: cwd.path)
        case .codex: startProcess(executable: "/usr/bin/env", args: ["codex"], environment: environment, execName: "codex", currentDirectory: cwd.path)
        default: startProcess(executable: shell, args: ["-l"], environment: environment, execName: "-\(URL(fileURLWithPath: shell).lastPathComponent)", currentDirectory: cwd.path)
        }
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        capturedOutput = String((capturedOutput + String(decoding: slice, as: UTF8.self)).suffix(1_048_576))
        super.dataReceived(slice: slice)
    }
}

struct TerminalPaneView: NSViewRepresentable {
    @Environment(AppModel.self) private var model
    let pane: Pane
    let session: Session

    func makeNSView(context: Context) -> HelmTerminalView {
        let view = model.terminalRegistry.terminal(for: pane, session: session, fontSize: model.state.settings.terminalFontSize)
        view.sessionID = session.id
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ view: HelmTerminalView, context: Context) {
        let size = CGFloat(model.state.settings.terminalFontSize)
        if view.font.pointSize != size { view.font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular) }
    }
}
