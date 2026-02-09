//
//  DownloadCoverTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

@testable import ReadiumSwiftTestApp
import XCTest

/// Helper to intercept URL requests
class MockURLProtocol: URLProtocol {
    // MARK: - Thread-Safe Storage

    /// A lock to protect access to the shared request handler.
    private static let lock = NSLock()

    /// The backing storage.
    private nonisolated(unsafe) static var _requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Public thread-safe accessor for the request handler.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
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

    // MARK: - URLProtocol Overrides

    override class func canInit(with _: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let handler = Self.requestHandler

        guard let handler = handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class DownloadCoverTests: XCTestCase {
    var downloadService: DownloadService!

    override func setUp() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let manager = DownloadManager(coverSession: mockSession)
        downloadService = DownloadService(manager: manager)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
    }

    func testDownloadCoverSuccess() async throws {
        let bookID = UUID()
        let url = try XCTUnwrap(URL(string: "https://example.com/cover.jpg"))
        let dummyData = "imagedata".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, url)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, dummyData)
        }

        do {
            let filename = try await downloadService.downloadCover(url: url, for: bookID)
            XCTAssertTrue(filename.contains(bookID.uuidString))
            XCTAssertTrue(filename.hasSuffix("jpg"))
        } catch {
            XCTFail("Expected success, but got error: \(error)")
        }
    }

    func testDownloadCoverNotFound() async throws {
        let bookID = UUID()
        let url = try XCTUnwrap(URL(string: "https://example.com/missing.jpg"))

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await downloadService.downloadCover(url: url, for: bookID)
            XCTFail("Expected failure, but succeeded")
        } catch {
            if case let .invalidResponse(code) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Expected invalidResponse(404), got \(error)")
            }
        }
    }

    func testDownloadCoverNetworkError() async throws {
        let bookID = UUID()
        let url = try XCTUnwrap(URL(string: "https://example.com/error"))

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await downloadService.downloadCover(url: url, for: bookID)
            XCTFail("Expected failure, but succeeded")
        } catch {
            if case let .network(urlError) = error {
                XCTAssertEqual(urlError.code, .notConnectedToInternet)
            } else {
                XCTFail("Expected network error, got \(error)")
            }
        }
    }
}
