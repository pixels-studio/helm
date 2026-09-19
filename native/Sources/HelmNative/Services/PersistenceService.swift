import Foundation

actor PersistenceService {
    private let stateURL: URL
    init(baseURL: URL? = nil) throws {
        let root = baseURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Helm", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        stateURL = root.appending(path: "state-v2.json")
    }

    func load() throws -> PersistedState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return PersistedState() }
        return try JSONDecoder.helm.decode(PersistedState.self, from: Data(contentsOf: stateURL))
    }

    func save(_ state: PersistedState) throws {
        let data = try JSONEncoder.helm.encode(state)
        let temporary = stateURL.appendingPathExtension("tmp")
        try data.write(to: temporary, options: [.atomic, .completeFileProtection])
        if FileManager.default.fileExists(atPath: stateURL.path) { _ = try FileManager.default.replaceItemAt(stateURL, withItemAt: temporary) }
        else { try FileManager.default.moveItem(at: temporary, to: stateURL) }
    }
}

private extension JSONEncoder {
    static var helm: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601; return e }
}
private extension JSONDecoder {
    static var helm: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
