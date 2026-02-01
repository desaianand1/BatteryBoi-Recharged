//
//  ProcessRunner.swift
//  BatteryBoi
//

import Foundation

enum ProcessRunnerError: Error {
    case timeout
    case executionFailed(String)
    case invalidOutput
    case nonZeroExitCode(Int32, String)
}

actor ProcessRunner {
    static let shared = ProcessRunner()

    private init() {}

    func run(
        executable: String,
        arguments: [String],
        timeout: Duration = .seconds(30),
    ) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.executeProcess(executable: executable, arguments: arguments)
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw ProcessRunnerError.timeout
            }

            guard let result = try await group.next() else {
                throw ProcessRunnerError.executionFailed("No result from process")
            }

            group.cancelAll()
            return result
        }
    }

    private func executeProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ProcessRunnerError.executionFailed(error.localizedDescription))
                return
            }

            process.terminationHandler = { terminatedProcess in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let exitCode = terminatedProcess.terminationStatus

                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: ProcessRunnerError.invalidOutput)
                    return
                }

                let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)

                if exitCode != 0 {
                    continuation.resume(throwing: ProcessRunnerError.nonZeroExitCode(exitCode, trimmedOutput))
                } else {
                    continuation.resume(returning: trimmedOutput)
                }
            }
        }
    }

    func runShell(command: String, timeout: Duration = .seconds(30)) async throws -> String {
        try await run(executable: "/bin/sh", arguments: ["-c", command], timeout: timeout)
    }
}
