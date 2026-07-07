//
//  DownloadCoverTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
@testable import ReadiumSwiftTestApp
import Testing

@Suite(.serialized) @MainActor
final class DownloadCoverTests {
    var downloadService: DownloadService

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let manager = DownloadManager(coverSession: mockSession)
        downloadService = DownloadService(manager: manager)
    }

    deinit {
        MockURLProtocol.requestHandler = nil
    }

    @Test func downloadCoverSuccess() async throws {
        let bookID = UUID()
        let url = try #require(URL(string: "https://example.com/cover.jpg"))
        let dummyData = "imagedata".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.url == url)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, dummyData, nil)
        }

        do {
            let filename = try await downloadService.downloadCover(url: url, for: bookID)
            #expect(filename.contains(bookID.uuidString))
            #expect(filename.hasSuffix("jpg"))
        } catch {
            Issue.record("Expected success, but got error: \(error)")
        }
    }

    @Test func downloadCoverNotFound() async throws {
        let bookID = UUID()
        let url = try #require(URL(string: "https://example.com/missing.jpg"))

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data(), nil)
        }

        do {
            _ = try await downloadService.downloadCover(url: url, for: bookID)
            Issue.record("Expected failure, but succeeded")
        } catch {
            if case let .invalidResponse(code) = error {
                #expect(code == 404)
            } else {
                Issue.record("Expected invalidResponse(404), got \(error)")
            }
        }
    }

    @Test func downloadCoverNetworkError() async throws {
        let bookID = UUID()
        let url = try #require(URL(string: "https://example.com/error"))

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await downloadService.downloadCover(url: url, for: bookID)
            Issue.record("Expected failure, but succeeded")
        } catch {
            if case let .network(urlError) = error {
                #expect(urlError.code == .notConnectedToInternet)
            } else {
                Issue.record("Expected network error, got \(error)")
            }
        }
    }
}
