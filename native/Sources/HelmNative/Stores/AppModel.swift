import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class AppModel {
    var state = PersistedState()
    var gitStatuses: [UUID: GitStatus] = [:]
    var selectedDiffPath: [UUID: String] = [:]
    var errors: [String] = []
    var isCreatingSession = false
    var searchText = ""

    @ObservationIgnored let terminalRegistry = TerminalRegistry()
    @ObservationIgnored let browserRegistry = BrowserRegistry()
    @ObservationIgnored private let persistence: PersistenceService
    @ObservationIgnored private let git: GitService
    @ObservationIgnored private let worktrees: WorktreeService
    @ObservationIgnored let files = FileSystemService()
    @ObservationIgnored private var watcher: FileWatcher?

    init(baseURL: URL? = nil) {
        let runner = CommandRunner()
        git = GitService(runner: runner)
        persistence = try! PersistenceService(baseURL: baseURL)
        worktrees = try! WorktreeService(git: git, root: baseURL?.appending(path: "worktrees"))
        Task { await load() }
    }

    var selectedProject: Project? { state.projects.first { $0.id == state.selectedProjectID } }
    var selectedSession: Session? { state.sessions.first { $0.id == state.selectedSessionID } }
    func project(for session: Session) -> Project? { state.projects.first { $0.id == session.projectID } }
    func pane(_ id: UUID) -> Pane? { state.panes.first { $0.id == id } }
    func panes(for session: Session) -> [Pane] { session.workspace.root?.paneIDs.compactMap(pane) ?? [] }
    func sessions(for project: Project) -> [Session] {
        state.sessions.filter { $0.projectID == project.id && (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)) }
            .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    func load() async {
        do { state = try await persistence.load(); startWatchingSelectedSession(); await refreshGit() }
        catch { report(error) }
    }

    func addProject() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        if let existing = state.projects.first(where: { $0.path == canonical }) { selectProject(existing.id); return }
        let project = Project(id: UUID(), name: canonical.lastPathComponent, path: canonical, createdAt: .now, lastOpenedAt: .now)
        state.projects.append(project); state.selectedProjectID = project.id; state.selectedSessionID = nil; save()
    }

    func selectProject(_ id: UUID) {
        state.selectedProjectID = id
        if let index = state.projects.firstIndex(where: { $0.id == id }) { state.projects[index].lastOpenedAt = .now }
        if state.sessions.first(where: { $0.id == state.selectedSessionID })?.projectID != id { state.selectedSessionID = nil }
        save()
    }

    func removeProject(_ id: UUID) {
        let sessionIDs = Set(state.sessions.filter { $0.projectID == id }.map(\.id))
        sessionIDs.forEach { terminalRegistry.stop(sessionID: $0); browserRegistry.remove(sessionID: $0) }
        state.panes.removeAll { sessionIDs.contains($0.sessionID) }
        state.sessions.removeAll { $0.projectID == id }
        state.projects.removeAll { $0.id == id }
        if state.selectedProjectID == id { state.selectedProjectID = nil; state.selectedSessionID = nil }
        save()
    }

    func createSession(title: String, base: String, useWorktree: Bool) async -> Bool {
        guard let project = selectedProject, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            let id = UUID(); let worktree: URL; let branch: String?
            if useWorktree { (worktree, branch) = try await worktrees.create(project: project, sessionID: id, title: title, base: base) }
            else { worktree = project.path; branch = (await git.status(at: project.path)).branch }
            let session = Session(id: id, projectID: project.id, title: title, branch: branch, worktreeURL: worktree, ownsWorktree: useWorktree, createdAt: .now, lastOpenedAt: .now, workspace: WorkspaceLayout())
            state.sessions.append(session); state.selectedSessionID = id; save(); startWatchingSelectedSession(); await refreshGit(); return true
        } catch { report(error); return false }
    }

    func branches() async -> [String] {
        guard let project = selectedProject else { return [] }
        do { return try await git.branches(at: project.path) } catch { report(error); return [] }
    }

    func selectSession(_ id: UUID) {
        state.selectedSessionID = id
        if let index = state.sessions.firstIndex(where: { $0.id == id }) { state.sessions[index].lastOpenedAt = .now; state.selectedProjectID = state.sessions[index].projectID }
        save(); startWatchingSelectedSession(); Task { await refreshGit() }
    }

    func removeSession(_ id: UUID) async {
        guard let session = state.sessions.first(where: { $0.id == id }) else { return }
        do {
            if session.ownsWorktree { try await worktrees.remove(session: session) }
            terminalRegistry.stop(sessionID: id); browserRegistry.remove(sessionID: id)
            state.panes.removeAll { $0.sessionID == id }; state.sessions.removeAll { $0.id == id }
            if state.selectedSessionID == id { state.selectedSessionID = nil }
            save()
        } catch { report(error) }
    }

    func addPane(_ kind: PaneKind, axis: SplitAxis = .horizontal) {
        guard let sessionID = state.selectedSessionID,
              let sessionIndex = state.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let pane = Pane(sessionID: sessionID, kind: kind); state.panes.append(pane)
        state.sessions[sessionIndex].workspace.add(pane.id, axis: axis); save()
    }

    func focusPane(_ id: UUID) {
        guard let pane = pane(id), let index = state.sessions.firstIndex(where: { $0.id == pane.sessionID }) else { return }
        state.sessions[index].workspace.focusedPaneID = id; save()
    }

    func closePane(_ id: UUID) {
        guard let pane = pane(id), let index = state.sessions.firstIndex(where: { $0.id == pane.sessionID }) else { return }
        terminalRegistry.stop(paneID: id); browserRegistry.remove(paneID: id)
        state.panes.removeAll { $0.id == id }
        state.sessions[index].workspace.root = state.sessions[index].workspace.root?.removing(id)
        state.sessions[index].workspace.focusedPaneID = state.sessions[index].workspace.root?.paneIDs.first
        save()
    }

    func updateSplit(path: [Bool], fraction: Double) {
        guard let id = state.selectedSessionID, let index = state.sessions.firstIndex(where: { $0.id == id }), let root = state.sessions[index].workspace.root else { return }
        state.sessions[index].workspace.root = root.replacingFraction(at: path, with: fraction); save()
    }

    func updatePane(_ pane: Pane) { if let i = state.panes.firstIndex(where: { $0.id == pane.id }) { state.panes[i] = pane; save() } }

    func refreshGit() async {
        guard let session = selectedSession else { return }
        gitStatuses[session.id] = await git.status(at: session.worktreeURL)
    }

    func diff(for path: String) async -> String {
        guard let session = selectedSession else { return "" }
        do { return try await git.diff(path: path, at: session.worktreeURL) } catch { report(error); return "" }
    }

    func save() { let snapshot = state; Task { do { try await persistence.save(snapshot) } catch { await MainActor.run { report(error) } } } }
    func report(_ error: Error) { errors.append(error.localizedDescription) }
    func dismissError() { if !errors.isEmpty { errors.removeFirst() } }

    private func startWatchingSelectedSession() {
        watcher?.stop(); watcher = nil
        guard let session = selectedSession else { return }
        let next = FileWatcher(); next.start(url: session.worktreeURL) { [weak self] in Task { @MainActor in await self?.refreshGit() } }; watcher = next
    }
}
