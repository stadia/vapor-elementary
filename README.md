# Elementary: HTML Templating in Pure Swift

**A modern and efficient HTML rendering library - inspired by SwiftUI, built for the web.**

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fvapor-community%2Fvapor-elementary%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/vapor-community/vapor-elementary)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fvapor-community%2Fvapor-elementary%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/vapor-community/vapor-elementary)

## Vapor 5 beta fork

The `feat/vapor5-beta4` branch targets **Vapor 5.0.0-beta.4**, **Swift 6.4**,
and macOS/iOS/tvOS/watchOS 26.2 or Linux. Pin a verified commit when consuming
this experimental branch; the upstream main branch remains on Vapor 4.

Responses use Swift HTTP Types (`HTTPFields`) and Vapor's borrowed
`HTTPBodyWriter`. A backpressured Async Algorithms channel bridges Elementary's
escapable renderer to that writer. The renderer runs as a structured child task
and is cancelled when transport writing fails. Non-sendable HTML remains
single-use; sendable HTML can be rendered for more than one response.

Run `swift test` for status, headers, UTF-8, multi-chunk output, rendering errors,
consumer failures, and sendability regression tests.

This package helps you serve [Elementary](https://swiftpackageindex.com/elementary-swift/elementary) HTML web apps with Vapor.

Simply wrap `HTMLResponse` around your HTML content and return it from your routes.

```swift
import Vapor
import VaporElementary

let app = try Application()

app.get("index") { _ in
    HTMLResponse {
        MyIndexPage()
    }
}
```

Check out the docs in the [Elementary repo](https://github.com/elementary-swift/elementary) for more information.
