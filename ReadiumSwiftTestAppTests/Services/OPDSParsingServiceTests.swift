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

@Suite(.serialized) @MainActor
final class OPDSParsingServiceTests {
    init() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    deinit {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
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
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/opds+json"]
            )!
            return (response, jsonString.data(using: .utf8), nil)
        }

        // Inject DefaultHTTPClient with mock config
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
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
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/opds+json"]
            )!
            return (response, nil, NSError(domain: "test", code: -1, userInfo: nil))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = DefaultHTTPClient(configuration: config)

        let service = ReadiumOPDSParsingService(client: client)

        let url = try #require(URL(string: "https://example.com/fail.json"))

        await #expect(throws: Error.self) {
            _ = try await service.parseURL(url: url)
        }
    }
}
