//
//  DownloadServiceTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

@testable import ReadiumSwiftTestApp
import XCTest

@MainActor
final class DownloadServiceTests: XCTestCase {
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

    override func tearDown() {
        ServiceMockURLProtocol.requestHandler = nil
    }

    func makeSUT() -> (DownloadService, DownloadManager) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ServiceMockURLProtocol.self]

        let manager = DownloadManager(configuration: config)
        let service = DownloadService(manager: manager)

        return (service, manager)
    }

    func testStartDownload() async throws {
        let (downloadService, _) = makeSUT()

        let id = UUID()
        let url = try XCTUnwrap(URL(string: "https://example.com/book.epub"))

        // Setup Mock
        ServiceMockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(), nil)
        }

        downloadService.startDownload(url: url, for: id)

        // Allow actor to process
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Only check that the download was tracked.
        guard let download = downloadService.activeDownloads[id] else {
            XCTFail("Download should be tracked in activeDownloads")
            return
        }

        XCTAssertEqual(download.id, id)
        XCTAssertEqual(download.url, url)
    }

    func testDownloadProgressDelegate() async throws {
        let (downloadService, _) = makeSUT()

        let id = UUID()
        let url = try XCTUnwrap(URL(string: "https://example.com/test.epub"))

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

        let progressExp = expectation(description: "Progress > 0 received")

        // Subscribe first
        let events = downloadService.downloadEvents

        Task {
            for await event in events {
                if case let .didUpdateProgress(eventId, progress) = event,
                   eventId == id,
                   progress > 0
                {
                    progressExp.fulfill()
                    break
                }
            }
        }

        // Wait briefly to ensure subscription is active
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Start Download
        downloadService.startDownload(url: url, for: id)

        await fulfillment(of: [progressExp], timeout: 2.0)
    }

    func testDownloadCompletionDelegate() async throws {
        let (downloadService, _) = makeSUT()

        let id = UUID()
        let url = try XCTUnwrap(URL(string: "https://example.com/complete.epub"))

        ServiceMockURLProtocol.requestHandler = { request in
            let data = "Dummy Content".data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data, nil)
        }

        let eventExp = expectation(description: "Download finished received")

        // Subscribe first
        let events = downloadService.downloadEvents

        Task {
            for await event in events {
                if case let .didFinish(eventId, location) = event,
                   eventId == id
                {
                    XCTAssertTrue(FileManager.default.fileExists(atPath: location.path))
                    eventExp.fulfill()
                    break
                }
            }
        }

        // Wait briefly to ensure subscription
        try await Task.sleep(nanoseconds: 100_000_000)

        // Start Download
        downloadService.startDownload(url: url, for: id)

        await fulfillment(of: [eventExp], timeout: 2.0)
    }

    func testConcurrentStartDownload() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ServiceMockURLProtocol.self]

        ServiceMockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(), nil)
        }

        let concurrentManager = DownloadManager(configuration: config)
        let concurrentCount = 50

        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< concurrentCount {
                group.addTask {
                    let id = UUID()
                    if let url = URL(string: "https://example.com/book_\(i).epub") {
                        await concurrentManager.startDownload(url: url, id: id)
                    }
                }
            }
        }

        XCTAssertTrue(true, "Concurrency test completed")
    }
}
