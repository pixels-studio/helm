import XCTest
@testable import HelmNative

final class ModelTests: XCTestCase {
    func testWorkspaceSplitsAndCollapses() {
        let a = UUID(), b = UUID(), c = UUID()
        var layout = WorkspaceLayout(); layout.add(a); layout.add(b); layout.add(c, beside: a, axis: .vertical)
        XCTAssertEqual(Set(layout.root?.paneIDs ?? []), Set([a, b, c]))
        layout.root = layout.root?.removing(b)
        XCTAssertEqual(Set(layout.root?.paneIDs ?? []), Set([a, c]))
    }

    func testPersistenceRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let service = try PersistenceService(baseURL: root)
        let project = Project(id: UUID(), name: "Example", path: root, createdAt: .now, lastOpenedAt: .now)
        var state = PersistedState(); state.projects = [project]; state.selectedProjectID = project.id
        try await service.save(state)
        let restored = try await service.load()
        XCTAssertEqual(restored.projects.first?.id, project.id)
        XCTAssertEqual(restored.projects.first?.name, project.name)
        XCTAssertEqual(restored.projects.first?.path, project.path)
        XCTAssertEqual(restored.selectedProjectID, project.id)
    }

    func testFileSystemRejectsEscapes() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let service = FileSystemService()
        do { _ = try await service.resolve("../outside", under: root); XCTFail("Expected confinement failure") }
        catch FileSystemError.outsideWorkspace { }
    }

    func testGitAndWorktreeVerticalSlice() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let repository = root.appending(path: "repository")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        let runner = CommandRunner()
        let git = GitService(runner: runner)
        _ = try await git.invoke(["init", "-b", "main"], at: repository)
        _ = try await git.invoke(["config", "user.name", "Helm Tests"], at: repository)
        _ = try await git.invoke(["config", "user.email", "helm@example.invalid"], at: repository)
        try Data("original\n".utf8).write(to: repository.appending(path: "sample.txt"))
        _ = try await git.invoke(["add", "sample.txt"], at: repository)
        _ = try await git.invoke(["commit", "-m", "Initial"], at: repository)

        let project = Project(id: UUID(), name: "Repository", path: repository, createdAt: .now, lastOpenedAt: .now)
        let sessionID = UUID()
        let worktrees = try WorktreeService(git: git, root: root.appending(path: "worktrees"))
        let (location, branch) = try await worktrees.create(project: project, sessionID: sessionID, title: "Native Session", base: "main")
        XCTAssertTrue(FileManager.default.fileExists(atPath: location.appending(path: "sample.txt").path))
        XCTAssertTrue(branch.hasPrefix("helm/native-session-"))

        try Data("changed\n".utf8).write(to: location.appending(path: "sample.txt"))
        let status = await git.status(at: location)
        XCTAssertEqual(status.changes.map(\.path), ["sample.txt"])
        let diff = try await git.diff(path: "sample.txt", at: location)
        XCTAssertTrue(diff.contains("changed"))

        let session = Session(id: sessionID, projectID: project.id, title: "Native Session", branch: branch, worktreeURL: location, ownsWorktree: true, createdAt: .now, lastOpenedAt: .now, workspace: WorkspaceLayout())
        do { try await worktrees.remove(session: session); XCTFail("Dirty worktree removal should be refused") }
        catch WorktreeError.dirty { }
        _ = try await git.invoke(["restore", "sample.txt"], at: location)
        try await worktrees.remove(session: session)
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.path))
    }
}
