//
//  OPDSParsingServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

import Foundation
import ReadiumOPDS
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

/// Independent MockURLProtocol for this test file
class OPDSMockURLProtocol: Foundation.URLProtocol {
    nonisolated(unsafe) static var mockData: Data?
    nonisolated(unsafe) static var mockError: Error?
    nonisolated(unsafe) static var mockStatusCode: Int = 200

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let error = OPDSMockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: OPDSMockURLProtocol.mockStatusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/opds+json"]
            )!

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            if let data = OPDSMockURLProtocol.mockData {
                client?.urlProtocol(self, didLoad: data)
            }

            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized) @MainActor
final class OPDSParsingServiceTests {
    init() {
        URLProtocol.registerClass(OPDSMockURLProtocol.self)
    }

    deinit {
        URLProtocol.unregisterClass(OPDSMockURLProtocol.self)
        OPDSMockURLProtocol.mockData = nil
        OPDSMockURLProtocol.mockError = nil
    }

    @Test func parseValidOPDS2Feed() async throws {
        let jsonString = """
        {
            "metadata": { "title": "Mock Feed" },
            "links": [ {"href": "self", "rel": "self"} ],
            "publications": [
                {
                    "metadata": { "title": "Book 1" },
                    "links": [ {"href": "book.epub", "rel": "http://opds-spec.org/acquisition"} ]
                }
            ]
        }
        """
        OPDSMockURLProtocol.mockData = jsonString.data(using: .utf8)

        // Inject DefaultHTTPClient with mock config
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OPDSMockURLProtocol.self]
        let client = DefaultHTTPClient(configuration: config)

        let service = ReadiumOPDSParsingService(client: client)

        let url = try #require(URL(string: "https://example.com/opds.json"), "Invalid URL")

        let feed = try await service.parseURL(url: url)

        #expect(feed != nil)
        #expect(feed?.metadata.title == "Mock Feed")
        #expect(feed?.publications.count == 1)
        #expect(feed?.publications.first?.metadata.title == "Book 1")
    }

    @Test func parseFailure() async throws {
        OPDSMockURLProtocol.mockError = NSError(domain: "test", code: -1, userInfo: nil)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OPDSMockURLProtocol.self]
        let client = DefaultHTTPClient(configuration: config)

        let service = ReadiumOPDSParsingService(client: client)

        let url = try #require(URL(string: "https://example.com/fail.json"))

        await #expect(throws: Error.self) {
            _ = try await service.parseURL(url: url)
        }
    }
}
