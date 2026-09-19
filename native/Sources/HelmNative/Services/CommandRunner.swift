import Foundation

struct CommandResult: Sendable {
    let stdout: Data
    let stderr: Data
    let status: Int32
    var output: String { String(decoding: stdout, as: UTF8.self) }
    var errorOutput: String { String(decoding: stderr, as: UTF8.self) }
}

enum CommandError: LocalizedError {
    case failed(executable: String, status: Int32, message: String)
    var errorDescription: String? {
        switch self { case .failed(let executable, let status, let message): "\(executable) exited \(status): \(message)" }
    }
}

actor CommandRunner {
    func run(_ executable: URL, arguments: [String], cwd: URL, environment: [String: String] = [:]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let output = Pipe(), errors = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = cwd
            process.standardOutput = output
            process.standardError = errors
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
            let outputTask = Task.detached { output.fileHandleForReading.readDataToEndOfFile() }
            let errorTask = Task.detached { errors.fileHandleForReading.readDataToEndOfFile() }
            process.terminationHandler = { process in
                Task {
                    let result = CommandResult(stdout: await outputTask.value, stderr: await errorTask.value, status: process.terminationStatus)
                    if result.status == 0 { continuation.resume(returning: result) }
                    else { continuation.resume(throwing: CommandError.failed(executable: executable.path, status: result.status, message: result.errorOutput)) }
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
