//
//  OPDSParsingService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
@preconcurrency import ReadiumOPDS
@preconcurrency import ReadiumShared

enum OPDSBrowserError: Error {
    case unknown
    case notAnOPDSFeed
    case networkError(Error)
    case invalidURL
}

/// Protocol definition for OPDS parsing.
@MainActor
protocol OPDSParsingService {
    func parseURL(url: URL) async throws -> Feed?
}

@MainActor
class ReadiumOPDSParsingService: OPDSParsingService {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func parseURL(url: URL) async throws -> Feed? {
        guard let httpURL = HTTPURL(url: url) else {
            throw OPDSBrowserError.invalidURL
        }

        let request = HTTPRequest(url: httpURL)
        let result = await client.fetch(request)

        switch result {
        case let .success(response):
            guard let data = response.body else { return nil }
            guard let httpResponse = HTTPURLResponse(
                url: response.url.url,
                statusCode: response.status.rawValue,
                httpVersion: nil,
                headerFields: response.headers
            ) else {
                return nil
            }

            // Parse off the main thread
            let parsedFeed: Feed? = await Task.detached(priority: .userInitiated) {
                // Try to parse as OPDS 1 (XML)
                if let parseData = try? OPDS1Parser.parse(xmlData: data, url: url, response: httpResponse) {
                    return parseData.feed
                }

                // Try to parse as OPDS 2 (JSON)
                if let parseData = try? OPDS2Parser.parse(jsonData: data, url: url, response: httpResponse) {
                    return parseData.feed
                }

                return nil
            }.value

            guard let feed = parsedFeed else {
                throw OPDSBrowserError.notAnOPDSFeed
            }
            return feed

        case let .failure(error):
            throw OPDSBrowserError.networkError(error)
        }
    }
}
