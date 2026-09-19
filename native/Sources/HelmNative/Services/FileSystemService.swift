import Foundation

enum FileSystemError: LocalizedError { case outsideWorkspace, tooLarge, binary }

actor FileSystemService {
    private let hidden = Set([".git", "node_modules", ".build", "build", "dist", ".svelte-kit"])

    func resolve(_ relativePath: String, under root: URL) throws -> URL {
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let target = root.appending(path: relativePath).standardizedFileURL.resolvingSymlinksInPath()
        guard target.path == base.path || target.path.hasPrefix(base.path + "/"), !target.pathComponents.contains(".git") else { throw FileSystemError.outsideWorkspace }
        return target
    }

    func list(_ relativePath: String = "", under root: URL) throws -> [FileEntry] {
        let directory = try resolve(relativePath, under: root)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            .compactMap { url in
                guard !hidden.contains(url.lastPathComponent) else { return nil }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { return nil }
                return FileEntry(url: url, isDirectory: values.isDirectory == true)
            }.sorted { $0.isDirectory != $1.isDirectory ? $0.isDirectory : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func readText(_ relativePath: String, under root: URL) throws -> String {
        let file = try resolve(relativePath, under: root)
        let data = try Data(contentsOf: file, options: [.mappedIfSafe])
        guard data.count <= 2 * 1024 * 1024 else { throw FileSystemError.tooLarge }
        guard !data.contains(0), let text = String(data: data, encoding: .utf8) else { throw FileSystemError.binary }
        return text
    }
}

final class FileWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    func start(url: URL, onChange: @escaping @Sendable () -> Void) {
        stop(); descriptor = open(url.path, O_EVTONLY); guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete, .extend], queue: .global(qos: .utility))
        var pending: DispatchWorkItem?
        source.setEventHandler { pending?.cancel(); let next = DispatchWorkItem(block: onChange); pending = next; DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: next) }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        self.source = source; source.resume()
    }
    func stop() { source?.cancel(); source = nil; descriptor = -1 }
    deinit { stop() }
}
