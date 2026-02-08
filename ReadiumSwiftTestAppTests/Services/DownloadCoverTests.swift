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
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data?, Error?))?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler unavailable")
            return
        }

        let (response, data, error) = handler(request)

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class DownloadCoverTests: XCTestCase {
    var downloadService: DownloadService!
    var session: URLSession!
    var manager: DownloadManager!

    override func setUp() async throws {
        try await super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        // Inject the mock session as the 'coverSession' into the Manager
        manager = DownloadManager(coverSession: session)

        // Inject the Manager into the Service
        downloadService = DownloadService(manager: manager)
    }

    override func tearDown() async throws {
        downloadService = nil
        manager = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        try await super.tearDown()
    }

    func testDownloadCoverSuccess() throws {
        let bookId = UUID()
        let coverURL = try XCTUnwrap(URL(string: "https://example.com/cover.jpg"))
        let imageData = "fake image data".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, imageData, nil)
        }

        let expectation = self.expectation(description: "Cover Downloaded")

        downloadService.downloadCover(url: coverURL, for: bookId) { filename in
            XCTAssertNotNil(filename)
            XCTAssertTrue(filename!.contains(bookId.uuidString))
            XCTAssertTrue(filename!.hasSuffix(".jpg"))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testDownloadCoverFailure() throws {
        let bookId = UUID()
        let coverURL = try XCTUnwrap(URL(string: "https://example.com/cover.jpg"))

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil, NSError(domain: "test", code: 404))
        }

        let expectation = self.expectation(description: "Cover Failed")

        downloadService.downloadCover(url: coverURL, for: bookId) { filename in
            XCTAssertNil(filename)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }
}
