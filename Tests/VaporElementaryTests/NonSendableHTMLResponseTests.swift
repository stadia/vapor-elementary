import Elementary
import Testing
import Vapor
import VaporElementary
import VaporTesting

@Suite("Sendability", .serialized)
struct NonSendableHTMLResponseTests {
    @Test func reusableSendableResponse() async throws {
        let html = HTMLResponse { p { "Hello" } }
        try await withApp { app in
            app.get { _ in html }
            try await app.testing { client in
                for _ in 0..<2 {
                    let response = try await client.get("/")
                    #expect(try await response.body.string() == "<p>Hello</p>")
                }
            }
        }
    }

    @Test func nonSendableHTML() async throws {
        try await withApp { app in
            app.get { _ in HTMLResponse { div { NonSendableHTML() } } }
            try await app.testing { client in
                let response = try await client.get("/")
                #expect(try await response.body.string() == "<div>Hello</div>")
            }
        }
    }
}

@available(*, unavailable)
extension NonSendableHTML: Sendable {}

struct NonSendableHTML: HTML {
    var body: some HTML { "Hello" }
}
