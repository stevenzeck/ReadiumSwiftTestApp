//
//  DownloadService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import Combine
import Foundation
import Observation

/// Specific errors that can occur during download operations.
public enum DownloadError: Error, Equatable {
    case network(URLError)
    case fileSystem(String)
    case invalidResponse(Int)
    case unknown(String)

    /// Helper to genericize other errors
    static func wrap(_ error: Error) -> DownloadError {
        if let urlError = error as? URLError {
            return .network(urlError)
        }
        return .unknown(error.localizedDescription)
    }
}

/// Represents the state of an active download task.
struct Download: Sendable {
    let id: UUID
    let url: URL
    var progress: Double = 0.0
    var isComplete: Bool = false
    var localURL: URL?
}

/// Events emitted by the DownloadManager.
public enum DownloadEvent: Sendable {
    case didFinish(id: UUID, location: URL)
    case didUpdateProgress(id: UUID, progress: Double)
    case didFail(id: UUID, error: DownloadError)
}

/// Actor responsible for handling background downloads.
actor DownloadManager: NSObject, URLSessionDownloadDelegate {
    let eventStream: AsyncStream<DownloadEvent>
    private let continuation: AsyncStream<DownloadEvent>.Continuation

    private var session: URLSession!
    private var coverSession: URLSession
    private var taskMap: [Int: UUID] = [:]

    init(session: URLSession? = nil, configuration: URLSessionConfiguration? = nil, coverSession: URLSession? = nil) {
        let (stream, cont) = AsyncStream.makeStream(of: DownloadEvent.self)
        eventStream = stream
        continuation = cont

        self.coverSession = coverSession ?? URLSession.shared

        super.init()

        if let session = session {
            self.session = session
        } else {
            let config = configuration ?? {
                let c = URLSessionConfiguration.background(withIdentifier: "com.example.ReadiumSwiftTestApp.background")
                c.isDiscretionary = false
                c.sessionSendsLaunchEvents = true
                return c
            }()
            self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        }
    }

    func startDownload(url: URL, id: UUID) {
        let task = session.downloadTask(with: url)
        taskMap[task.taskIdentifier] = id
        task.resume()
    }

    func downloadCover(url: URL, bookId: UUID) async throws(DownloadError) -> String {
        do {
            let (location, response) = try await coverSession.download(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DownloadError.unknown("Invalid response type")
            }

            guard httpResponse.statusCode == 200 else {
                throw DownloadError.invalidResponse(httpResponse.statusCode)
            }

            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filename = "\(bookId.uuidString)-cover.\(url.pathExtension)"
            let destination = documents.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.moveItem(at: location, to: destination)
            return filename
        } catch let error as DownloadError {
            throw error
        } catch let error as URLError {
            throw .network(error)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                throw .fileSystem(nsError.localizedDescription)
            }
            throw .unknown(error.localizedDescription)
        }
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempDst = tempDir.appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.moveItem(at: location, to: tempDst)
            Task {
                await self.finalizeDownload(taskID: downloadTask.taskIdentifier, tempLocation: tempDst, originalFilename: downloadTask.originalRequest?.url?.lastPathComponent)
            }
        } catch {
            print("Failed to move temp file: \(error)")
        }
    }

    nonisolated func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task {
            await self.updateProgress(taskID: downloadTask.taskIdentifier, written: totalBytesWritten, total: totalBytesExpectedToWrite)
        }
    }

    nonisolated func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task {
                await self.handleError(taskID: task.taskIdentifier, error: error)
            }
        }
    }

    // MARK: - Actor Logic

    private func finalizeDownload(taskID: Int, tempLocation: URL, originalFilename: String?) {
        defer {
            taskMap[taskID] = nil
            try? FileManager.default.removeItem(at: tempLocation)
        }

        guard let id = taskMap[taskID] else { return }

        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let rawFilename = originalFilename ?? "download.file"
            let uniqueFilename = "\(id.uuidString)_\(rawFilename)"

            let destination = documents.appendingPathComponent(uniqueFilename)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.moveItem(at: tempLocation, to: destination)
            continuation.yield(.didFinish(id: id, location: destination))
        } catch {
            let downloadError: DownloadError = (error as? DownloadError) ?? .fileSystem(error.localizedDescription)
            continuation.yield(.didFail(id: id, error: downloadError))
        }
    }

    private func updateProgress(taskID: Int, written: Int64, total: Int64) {
        guard let id = taskMap[taskID] else { return }
        guard total > 0 else { return }
        let progress = Double(written) / Double(total)
        continuation.yield(.didUpdateProgress(id: id, progress: progress))
    }

    private func handleError(taskID: Int, error: Error) {
        guard let id = taskMap[taskID] else { return }
        let downloadError = DownloadError.wrap(error)
        continuation.yield(.didFail(id: id, error: downloadError))
        taskMap[taskID] = nil
    }
}

/// Helper to safely capture AnyCancellable in AsyncStream closure.
private final class CancellableBox: @unchecked Sendable {
    private let cancelAction: @Sendable () -> Void

    init(_ cancellable: AnyCancellable) {
        cancelAction = { cancellable.cancel() }
    }

    nonisolated func cancel() {
        cancelAction()
    }
}

/// The MainActor service that the UI interacts with.
@Observable
@MainActor
class DownloadService {
    // MARK: - Published Properties

    var activeDownloads: [UUID: Download] = [:]

    // MARK: - Private

    private let manager: DownloadManager
    private let subject = PassthroughSubject<DownloadEvent, Never>()

    var downloadEvents: AsyncStream<DownloadEvent> {
        AsyncStream { continuation in
            let cancellable = subject.sink { event in
                continuation.yield(event)
            }
            let box = CancellableBox(cancellable)

            continuation.onTermination = { _ in
                box.cancel()
            }
        }
    }

    // MARK: - Initialization

    init(manager: DownloadManager? = nil) {
        self.manager = manager ?? DownloadManager()

        Task {
            for await event in self.manager.eventStream {
                self.handleEvent(event)
                self.subject.send(event)
            }
        }
    }

    // MARK: - Public Methods

    func startDownload(url: URL, for id: UUID) {
        let download = Download(id: id, url: url)
        activeDownloads[id] = download

        Task {
            await manager.startDownload(url: url, id: id)
        }
    }

    /// Downloads a cover image
    func downloadCover(url: URL, for bookId: UUID) async throws(DownloadError) -> String {
        return try await manager.downloadCover(url: url, bookId: bookId)
    }

    // MARK: - Internal Handling

    private func handleEvent(_ event: DownloadEvent) {
        switch event {
        case let .didFinish(id, location):
            if var download = activeDownloads[id] {
                download.isComplete = true
                download.localURL = location
                activeDownloads[id] = download

                Task {
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    activeDownloads[id] = nil
                }
            }
        case let .didUpdateProgress(id, progress):
            if var download = activeDownloads[id] {
                download.progress = progress
                activeDownloads[id] = download
            }
        case let .didFail(id, _):
            activeDownloads[id] = nil
        }
    }
}
