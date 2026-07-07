//
//  LibraryViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/22/26.
//

import Foundation
@testable import ReadiumSwiftTestApp
import SwiftData
import Testing

actor MockFileManager: FileManaging {
    let tempDir = URL(fileURLWithPath: "/tmp/mock-docs")

    var copyItemCalled = false
    var removeItemCalled = false
    var fileExistsResult = false
    var removeItemCount = 0

    func documentDirectoryURL() -> URL {
        return tempDir
    }

    func copyItem(at _: URL, to _: URL) throws {
        copyItemCalled = true
    }

    func removeItem(at _: URL) throws {
        removeItemCalled = true
        removeItemCount += 1
    }

    func fileExists(atPath _: String) -> Bool {
        return fileExistsResult
    }
}

@Suite(.serialized) @MainActor
final class LibraryViewModelTests {
    var viewModel: LibraryViewModel
    var mockFileManager: MockFileManager
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let container = try TestHelper.makeInMemoryContainer()
        self.container = container
        context = container.mainContext
        let mockFileManager = MockFileManager()
        self.mockFileManager = mockFileManager
        viewModel = LibraryViewModel(fileManager: mockFileManager)
    }

    @Test func deleteBook() async throws {
        let book = Book(title: "Delete Me", format: "epub", filePath: "delete.epub", coverPath: "cover.jpg")
        context.insert(book)
        try context.save()

        viewModel.deleteBook(book, modelContext: context)

        // Verify DB deletion immediately
        let books = try context.fetch(FetchDescriptor<Book>())
        #expect(books.isEmpty)

        // Verify file deletion async
        var attempts = 0
        while await mockFileManager.removeItemCount < 2, attempts < 200 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }

        // State checks on the actor
        let removed = await mockFileManager.removeItemCalled
        #expect(removed)
    }
}
