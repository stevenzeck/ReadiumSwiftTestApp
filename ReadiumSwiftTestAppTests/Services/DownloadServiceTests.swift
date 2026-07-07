//
//  DownloadServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

import Foundation
@testable import ReadiumSwiftTestApp
import Testing

@Suite(.serialized) @MainActor
final class DownloadServiceTests {
    // MARK: - Local Mock Protocol

    /// Unique class here to avoid colliding with DownloadCoverTests' MockURLProtocol
    private class ServiceMockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data?, Error?))?

        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let client = client, let handler = ServiceMockURLProtocol.requestHandler else { return }

            let (response, data, error) = handler(request)

            if let error = error {
                client.urlProtocol(self, didFailWithError: error)
                return
            }

            // Send Headers
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            // Send Data
            if let data = data {
                client.urlProtocol(self, didLoad: data)
            }

            // Finish
            client.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    deinit {
        ServiceMockURLProtocol.requestHandler = nil
    }

    func makeSUT() -> (DownloadService, DownloadManager) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ServiceMockURLProtocol.self]

        let manager = DownloadManager(configuration: config)
        let service = DownloadService(manager: manager)

        return (service, manager)
    }

    @Test func startDownload() async throws {
        let (downloadService, _) = makeSUT()

        let id = UUID()
        let url = try #require(URL(string: "https://example.com/book.epub"))

        // Setup Mock
        ServiceMockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(), nil)
        }

        downloadService.startDownload(url: url, for: id)

        // Allow actor to process
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Only check that the download was tracked.
        let download = try #require(downloadService.activeDownloads[id], "Download should be tracked in activeDownloads")

        #expect(download.id == id)
        #expect(download.url == url)
    }

    @Test func downloadProgressDelegate() async throws {
        let (downloadService, _) = makeSUT()

        let id = UUID()
        let url = try #require(URL(string: "https://example.com/test.epub"))

        // Setup Mock with Content-Length so progress can be calculated
        ServiceMockURLProtocol.requestHandler = { request in
            let data = Data(count: 1024)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "1024"]
            )!
            return (response, data, nil)
        }

        // 1. Get the stream (Await access to the actor)
        let stream = await downloadService.downloadEvents

        // 2. Start listener task
        let listenerTask = Task {
            for await event in stream {
                if case let .didUpdateProgress(eventId, progress) = event,
                   eventId == id,
                   progress > 0
                {
                    return true
                }
            }
            return false
        }

        // Wait briefly to ensure subscription is active
        try await Task.sleep(nanoseconds: 100_000_000)

        // 3. Start Download
        downloadService.startDownload(url: url, for: id)

        let receivedProgress = await listenerTask.value
        #expect(receivedProgress)
    }

    @Test func downloadCompletionDelegate() async throws {
        let (downloadService, _) = makeSUT()

        let id = UUID()
        let url = try #require(URL(string: "https://example.com/complete.epub"))

        ServiceMockURLProtocol.requestHandler = { request in
            let data = "Dummy Content".data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data, nil)
        }

        // 1. Get the stream
        let stream = await downloadService.downloadEvents

        // 2. Start listener
        let listenerTask = Task {
            for await event in stream {
                if case let .didFinish(eventId, location) = event,
                   eventId == id
                {
                    return FileManager.default.fileExists(atPath: location.path)
                }
            }
            return false
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        downloadService.startDownload(url: url, for: id)

        let finished = await listenerTask.value
        #expect(finished)
    }
}
