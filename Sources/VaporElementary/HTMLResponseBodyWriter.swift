import AsyncAlgorithms
import Elementary
import Vapor

// Elementary's writer is escapable; Vapor's HTTP writer is borrowed. A channel
// bridges the two without escaping the HTTP writer or buffering the full page.
private struct HTMLResponseBodyStreamWriter: HTMLStreamWriter {
    let channel: AsyncThrowingChannel<[UInt8], any Error>

    mutating func write(_ bytes: ArraySlice<UInt8>) async throws {
        try Task.checkCancellation()
        await channel.send(Array(bytes))
        try Task.checkCancellation()
    }
}

public extension HTTPBodyWriter where Self: ~Escapable {
    /// Render HTML incrementally, suspending the producer while the client is slow.
    nonisolated(nonsending) func writeHTML(_ html: sending some HTML & SendableMetatype, chunkSize: Int = 1024) async throws {
        try await renderHTML(_SendableAnyHTMLBox(html), chunkSize: chunkSize)
    }
}

extension HTTPBodyWriter where Self: ~Escapable {
    nonisolated(nonsending) func renderHTML(_ value: _SendableAnyHTMLBox, chunkSize: Int) async throws {
        let channel = AsyncThrowingChannel<[UInt8], any Error>()
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    guard let html = value.tryTake() else {
                        throw Abort(.internalServerError, reason: "Non-sendable HTML response already consumed")
                    }
                    try await html.render(into: HTMLResponseBodyStreamWriter(channel: channel), chunkSize: chunkSize)
                    channel.finish()
                } catch {
                    channel.fail(error)
                    throw error
                }
            }
            defer {
                group.cancelAll()
                channel.finish()
            }
            for try await bytes in channel {
                try await self.write(bytes)
            }
            try await group.waitForAll()
        }
    }
}
