import Elementary
import HTTPTypes
import Logging
import Vapor

/// Represents a response that contains HTML content.
///
/// The generated `Response` will have the content type header set to `text/html; charset=utf-8` and a status of `.ok`.
/// The content is rendered in chunks of HTML and streamed in the response body.
///
/// ```swift
/// app.get("hello") { req in
///   HTMLResponse {
///     div {
///       p { "Hello!" }
///     }
///   }
/// }
/// ```
///
/// - Note: A non-sendable HTML value can be rendered only once. Encoding the response again throws
///   ``HTMLResponseError/alreadyConsumed`` from the body stream, after the `200` head has been sent.
///   Sendable HTML can be rendered any number of times.
public struct HTMLResponse: Sendable {
    private let value: _SendableAnyHTMLBox

    /// The number of bytes to write to the response body at a time.
    ///
    /// The default is 1024 bytes.
    public var chunkSize: Int

    /// Response headers
    ///
    /// It can be used to add additional headers to a predefined set of fields.
    ///
    /// - Note: If a new set of headers is assigned, all predefined headers are removed.
    ///
    /// ```swift
    /// var response = HTMLResponse { ... }
    /// response.headers[HTTPField.Name("Foo")!] = "bar"
    /// return response
    /// ```
    public var headers: HTTPFields

    /// Creates a new HTMLResponse
    ///
    /// - Parameters:
    ///   - chunkSize: The number of bytes to write to the response body at a time.
    ///   - additionalHeaders: Additional headers. A `Content-Type` given here replaces the default.
    ///   - content: The `HTML` content to render in the response.
    public init(chunkSize: Int = 1024, additionalHeaders: HTTPFields = [:], @HTMLBuilder content: () -> some HTML & Sendable) {
        self.init(chunkSize: chunkSize, additionalHeaders: additionalHeaders, value: .init(content()))
    }

    /// Creates a new HTMLResponse from non-sendable content, which can be rendered only once.
    ///
    /// - Parameters:
    ///   - chunkSize: The number of bytes to write to the response body at a time.
    ///   - additionalHeaders: Additional headers. A `Content-Type` given here replaces the default.
    ///   - content: The `HTML` content to render in the response.
    public init(chunkSize: Int = 1024, additionalHeaders: HTTPFields = [:], @HTMLBuilder content: () -> sending some HTML) {
        self.init(chunkSize: chunkSize, additionalHeaders: additionalHeaders, value: .init(content()))
    }

    init(chunkSize: Int, additionalHeaders: HTTPFields = [:], value: _SendableAnyHTMLBox) {
        self.chunkSize = chunkSize
        self.headers = additionalHeaders
        if self.headers[.contentType] == nil {
            self.headers[.contentType] = "text/html; charset=utf-8"
        }
        self.value = value
    }
}

extension HTMLResponse: ResponseEncodable {
    nonisolated(nonsending) public func encodeResponse(for request: Request) async throws -> Response {
        let value = self.value
        let chunkSize = self.chunkSize
        // A named function preserves the borrowed writer's nonsending isolation.
        @Sendable nonisolated(nonsending) func stream(_ writer: borrowing any HTTPBodyWriter & ~Escapable) async throws {
            do {
                try await writer.renderHTML(value, chunkSize: chunkSize)
            } catch HTMLResponseError.alreadyConsumed {
                // The 200 head is already sent, so the log is the only place this misuse shows up.
                Logger.current.error("Non-sendable HTML response encoded more than once")
                throw HTMLResponseError.alreadyConsumed
            }
        }
        return Response(status: .ok, headers: self.headers, body: .init(stream: stream))
    }
}
