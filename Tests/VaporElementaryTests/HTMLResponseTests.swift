import Elementary
import HTTPTypes
import Synchronization
import Testing
import Vapor
import VaporElementary
import VaporTesting

@Suite("HTML responses", .serialized)
struct HTMLResponseTests {
    @Test func statusAndContentType() async throws {
        try await withApp { app in
            app.get { _ in HTMLResponse { EmptyHTML() } }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(response.status == .ok)
                #expect(response.headers[.contentType] == "text/html; charset=utf-8")
                #expect(try await response.body.string() ?? "" == "")
            }
        }
    }

    @Test func documentAndKoreanText() async throws {
        try await withApp { app in
            app.get { _ in HTMLResponse { TestPage() } }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(try await response.body.string() == "<!DOCTYPE html><html lang=\"ko\"><head><meta charset=\"UTF-8\"><title>소식</title></head><body><h1>Swift 소식</h1></body></html>")
            }
        }
    }

    @Test func fragmentAndLargeStream() async throws {
        try await withApp { app in
            app.get { _ in
                HTMLResponse(chunkSize: 32) {
                    for _ in 0..<1000 { p { "한글 & <Swift>" } }
                }
            }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(try await response.body.string() == String(repeating: "<p>한글 &amp; &lt;Swift&gt;</p>", count: 1000))
            }
        }
    }

    @Test func customHeadersAndContentType() async throws {
        try await withApp { app in
            app.get { _ in
                var response = HTMLResponse(additionalHeaders: [.vary: "HX-Request", .contentType: "text/custom"]) { p { "OK" } }
                response.headers[HTTPField.Name("HX-Refresh")!] = "true"
                return response
            }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(response.headers[.contentType] == "text/custom")
                #expect(response.headers[.vary] == "HX-Request")
                #expect(response.headers[HTTPField.Name("HX-Refresh")!] == "true")
                #expect(try await response.body.string() == "<p>OK</p>")
            }
        }
    }

    @Test func additionalHeadersKeepDefaultContentType() async throws {
        try await withApp { app in
            app.get { _ in HTMLResponse(additionalHeaders: [.vary: "HX-Request"]) { p { "OK" } } }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(response.headers[.contentType] == "text/html; charset=utf-8")
                #expect(response.headers[.vary] == "HX-Request")
            }
        }
    }

    @Test func writesToVaporStream() async throws {
        try await withApp { app in
            app.get { _ in
                Response(body: .init(stream: { writer in
                    try await writer.writeHTML(p { "Hello" })
                }))
            }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(try await response.body.string() == "<p>Hello</p>")
            }
        }
    }
}

struct TestPage: HTMLDocument, Sendable {
    var title: String { "소식" }
    var lang: String { "ko" }
    var head: some HTML { EmptyHTML() }
    var body: some HTML { h1 { "Swift 소식" } }
}

private enum RenderFailure: Error { case expected }

@Suite("Streaming failures", .serialized)
struct StreamingFailureTests {
    @Test(.timeLimit(.minutes(1))) func renderingErrorIsPropagated() async throws {
        try await withApp { app in
            app.get { _ in
                HTMLResponse {
                    AsyncContent {
                        try await failingContent()
                    }
                }
            }
            try await app.testing { client in
                let response = try await client.get("/")
                await #expect(throws: RenderFailure.self) {
                    _ = try await response.body.string()
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(1))) func consumerFailureStopsRenderer() async throws {
        let rendered = Mutex(0)
        try await withApp { app in
            app.get { _ in
                HTMLResponse(chunkSize: 1) {
                    for _ in 0..<10000 {
                        AsyncContent {
                            rendered.withLock { $0 += 1 }
                            return p { "chunk" }
                        }
                    }
                }
            }
            try await app.testing { client in
                let response = try await client.get("/")
                await #expect(throws: RenderFailure.self) {
                    try await response.body.withStreamingBytes { _ in throw RenderFailure.expected }
                }
            }
        }
        // withApp has shut the server down, so the renderer has stopped; it must not have run to the end.
        #expect(rendered.withLock { $0 } < 10000)
    }
}

private func failingContent() async throws -> EmptyHTML {
    await Task.yield()
    throw RenderFailure.expected
}
