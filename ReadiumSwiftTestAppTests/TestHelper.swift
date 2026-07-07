//
//  TestHelper.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

import Foundation
@testable import ReadiumSwiftTestApp
import SwiftData

class TestHelper {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Book.self,
            OPDSFeed.self,
            Bookmark.self,
            Highlight.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

/// A thread-safe, unified mock URLProtocol for intercepting network requests in unit tests.
class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?, Error?))?

    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?, Error?))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _requestHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _requestHandler = newValue
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let client = client, let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data, error) = try handler(request)

            if let error = error {
                client.urlProtocol(self, didFailWithError: error)
                return
            }

            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            if let data = data {
                client.urlProtocol(self, didLoad: data)
            }

            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
