import Foundation

actor GitService {
    private let runner: CommandRunner
    private let git = URL(fileURLWithPath: "/usr/bin/git")
    init(runner: CommandRunner) { self.runner = runner }

    func isRepository(at cwd: URL) async -> Bool { (try? await invoke(["rev-parse", "--show-toplevel"], at: cwd)) != nil }

    func branches(at cwd: URL) async throws -> [String] {
        try await invoke(["for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes"], at: cwd)
            .split(separator: "\n").map(String.init)
    }

    func status(at cwd: URL) async -> GitStatus {
        guard await isRepository(at: cwd) else { return GitStatus(isRepository: false, branch: "", changes: []) }
        let branch = (try? await invoke(["rev-parse", "--abbrev-ref", "HEAD"], at: cwd).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "unborn"
        let raw = (try? await invoke(["status", "--porcelain=v1", "-z", "--untracked-files=all"], at: cwd)) ?? ""
        let records = raw.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        var changes: [GitChange] = [], skip = false
        for record in records {
            if skip { skip = false; continue }
            guard record.count >= 4 else { continue }
            let chars = Array(record)
            changes.append(GitChange(path: String(chars.dropFirst(3)), indexStatus: chars[0], worktreeStatus: chars[1]))
            skip = chars[0] == "R" || chars[0] == "C" || chars[1] == "R" || chars[1] == "C"
        }
        return GitStatus(isRepository: true, branch: branch, changes: changes)
    }

    func diff(path: String, at cwd: URL) async throws -> String {
        guard !path.contains("\0"), !path.split(separator: "/").contains("..") else { throw CocoaError(.fileReadInvalidFileName) }
        return try await invoke(["diff", "HEAD", "--", path], at: cwd)
    }

    func stage(path: String, at cwd: URL) async throws { _ = try await invoke(["add", "--", path], at: cwd) }
    func unstage(path: String, at cwd: URL) async throws { _ = try await invoke(["restore", "--staged", "--", path], at: cwd) }
    func discard(path: String, at cwd: URL) async throws { _ = try await invoke(["restore", "--worktree", "--", path], at: cwd) }

    func invoke(_ arguments: [String], at cwd: URL) async throws -> String {
        try await runner.run(git, arguments: arguments, cwd: cwd, environment: ["GIT_TERMINAL_PROMPT": "0"]).output
    }
}
