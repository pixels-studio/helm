import Foundation

enum WorktreeError: LocalizedError {
    case invalidBase, dirty
    var errorDescription: String? { self == .dirty ? "Worktree has uncommitted changes." : "Choose a valid base branch." }
}

actor WorktreeService {
    private let git: GitService
    private let root: URL
    init(git: GitService, root: URL? = nil) throws {
        self.git = git
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Helm/worktrees", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func create(project: Project, sessionID: UUID, title: String, base: String) async throws -> (URL, String) {
        guard !base.isEmpty, !base.hasPrefix("-") else { throw WorktreeError.invalidBase }
        _ = try await git.invoke(["rev-parse", "--verify", "\(base)^{commit}"], at: project.path)
        let slug = title.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let branch = "helm/\(slug.isEmpty ? "session" : slug)-\(sessionID.uuidString.prefix(8).lowercased())"
        let location = root.appending(path: project.id.uuidString, directoryHint: .isDirectory).appending(path: sessionID.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: location.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try await git.invoke(["worktree", "add", "-b", branch, location.path, base], at: project.path)
        return (location, branch)
    }

    func remove(session: Session) async throws {
        guard (await git.status(at: session.worktreeURL)).changes.isEmpty else { throw WorktreeError.dirty }
        _ = try await git.invoke(["worktree", "remove", session.worktreeURL.path], at: session.worktreeURL)
    }
}
