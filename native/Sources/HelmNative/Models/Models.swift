import Foundation

struct Project: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var path: URL
    var createdAt: Date
    var lastOpenedAt: Date
}

enum PaneKind: String, Codable, CaseIterable, Sendable {
    case claude, codex, terminal, file, diff, git, browser

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .terminal: "Terminal"
        case .file: "File"
        case .diff: "Code Diff"
        case .git: "Git"
        case .browser: "Browser"
        }
    }

    var symbol: String {
        switch self {
        case .claude: "sun.max.fill"
        case .codex: "circle.hexagongrid.fill"
        case .terminal: "terminal.fill"
        case .file: "doc.text.fill"
        case .diff: "plus.forwardslash.minus"
        case .git: "point.3.connected.trianglepath.dotted"
        case .browser: "globe"
        }
    }
}

struct Pane: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sessionID: UUID
    var kind: PaneKind
    var title: String
    var filePath: String?
    var browserURL: URL?

    init(id: UUID = UUID(), sessionID: UUID, kind: PaneKind) {
        self.id = id
        self.sessionID = sessionID
        self.kind = kind
        self.title = kind.title
        self.browserURL = kind == .browser ? URL(string: "http://localhost:5173") : nil
    }
}

enum SplitAxis: String, Codable, Sendable { case horizontal, vertical }

indirect enum WorkspaceNode: Codable, Hashable, Sendable {
    case pane(UUID)
    case split(axis: SplitAxis, fraction: Double, first: WorkspaceNode, second: WorkspaceNode)

    var paneIDs: [UUID] {
        switch self {
        case .pane(let id): [id]
        case .split(_, _, let first, let second): first.paneIDs + second.paneIDs
        }
    }

    func removing(_ id: UUID) -> WorkspaceNode? {
        switch self {
        case .pane(let paneID): paneID == id ? nil : self
        case .split(let axis, let fraction, let first, let second):
            switch (first.removing(id), second.removing(id)) {
            case (nil, nil): nil
            case (let remaining?, nil), (nil, let remaining?): remaining
            case (let lhs?, let rhs?): .split(axis: axis, fraction: fraction, first: lhs, second: rhs)
            }
        }
    }

    func replacingFraction(at path: [Bool], with fraction: Double) -> WorkspaceNode {
        guard !path.isEmpty else {
            if case .split(let axis, _, let first, let second) = self {
                return .split(axis: axis, fraction: min(0.8, max(0.2, fraction)), first: first, second: second)
            }
            return self
        }
        guard case .split(let axis, let old, let first, let second) = self else { return self }
        let tail = Array(path.dropFirst())
        return path[0]
            ? .split(axis: axis, fraction: old, first: first, second: second.replacingFraction(at: tail, with: fraction))
            : .split(axis: axis, fraction: old, first: first.replacingFraction(at: tail, with: fraction), second: second)
    }
}

struct WorkspaceLayout: Codable, Hashable, Sendable {
    var root: WorkspaceNode?
    var focusedPaneID: UUID?

    mutating func add(_ paneID: UUID, beside target: UUID? = nil, axis: SplitAxis = .horizontal) {
        guard let root else { self.root = .pane(paneID); focusedPaneID = paneID; return }
        let anchor = target ?? focusedPaneID ?? root.paneIDs.last
        self.root = inserting(paneID, beside: anchor, in: root, axis: axis)
        focusedPaneID = paneID
    }

    private func inserting(_ paneID: UUID, beside target: UUID?, in node: WorkspaceNode, axis: SplitAxis) -> WorkspaceNode {
        switch node {
        case .pane(let id) where id == target:
            .split(axis: axis, fraction: 0.5, first: node, second: .pane(paneID))
        case .pane: node
        case .split(let existingAxis, let fraction, let first, let second):
            .split(axis: existingAxis, fraction: fraction,
                   first: inserting(paneID, beside: target, in: first, axis: axis),
                   second: inserting(paneID, beside: target, in: second, axis: axis))
        }
    }
}

struct Session: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let projectID: UUID
    var title: String
    var branch: String?
    var worktreeURL: URL
    var ownsWorktree: Bool
    var createdAt: Date
    var lastOpenedAt: Date
    var workspace: WorkspaceLayout
}

struct HelmSettings: Codable, Hashable, Sendable {
    var terminalFontSize: Double = 13
}

struct PersistedState: Codable, Sendable {
    var version = 2
    var projects: [Project] = []
    var sessions: [Session] = []
    var panes: [Pane] = []
    var selectedProjectID: UUID?
    var selectedSessionID: UUID?
    var settings = HelmSettings()
}

struct GitChange: Identifiable, Hashable, Sendable {
    var id: String { path }
    let path: String
    let indexStatus: Character
    let worktreeStatus: Character
    var statusLabel: String { String([indexStatus, worktreeStatus]).trimmingCharacters(in: .whitespaces) }
}

struct GitStatus: Sendable {
    let isRepository: Bool
    let branch: String
    let changes: [GitChange]
}

struct FileEntry: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let isDirectory: Bool
    var name: String { url.lastPathComponent }
}
