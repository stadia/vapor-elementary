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

/// Errors thrown while streaming an ``HTMLResponse``.
public enum HTMLResponseError: Error, Sendable {
    /// A non-sendable HTML value was rendered a second time.
    case alreadyConsumed
}

public extension HTTPBodyWriter where Self: ~Escapable {
    /// Render HTML incrementally, suspending the producer while the client is slow.
    ///
    /// The caller does not need to write an end marker. Rendering stops cooperatively when
    /// writing fails or the task is cancelled.
    ///
    /// - Parameters:
    ///   - html: The HTML content to render, consumed by this call.
    ///   - chunkSize: The number of bytes to write at a time (default is 1024 bytes).
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
                        throw HTMLResponseError.alreadyConsumed
                    }
                    try await html.render(into: HTMLResponseBodyStreamWriter(channel: channel), chunkSize: chunkSize)
                    channel.finish()
                } catch {
                    channel.fail(error)
                    throw error
                }
            }
            // Order matters: cancel first so the producer's post-send check turns the
            // dropped send from finish() into a CancellationError instead of a silent success.
            defer {
                group.cancelAll()
                channel.finish()
            }
            for try await bytes in channel {
                try await self.write(bytes)
            }
            // A cancelled consumer sees nil from the channel; never report that as a complete body.
            try Task.checkCancellation()
            try await group.waitForAll()
        }
    }
}
