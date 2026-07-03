//
//  LibraryViewModelTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/22/26.
//

@testable import ReadiumSwiftTestApp
import SwiftData
import XCTest

actor MockFileManager: FileManaging {
    let tempDir = URL(fileURLWithPath: "/tmp/mock-docs")

    var copyItemCalled = false
    var removeItemCalled = false
    var fileExistsResult = false
    var removeItemExpectation: XCTestExpectation?

    func setRemoveItemExpectation(_ expectation: XCTestExpectation) {
        removeItemExpectation = expectation
    }

    func documentDirectoryURL() -> URL {
        return tempDir
    }

    func copyItem(at _: URL, to _: URL) throws {
        copyItemCalled = true
    }

    func removeItem(at _: URL) throws {
        removeItemCalled = true
        removeItemExpectation?.fulfill()
    }

    func fileExists(atPath _: String) -> Bool {
        return fileExistsResult
    }
}

@MainActor
final class LibraryViewModelTests: XCTestCase {
    var viewModel: LibraryViewModel!
    var mockFileManager: MockFileManager!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try TestHelper.makeInMemoryContainer()
        context = container.mainContext
        mockFileManager = MockFileManager()
        viewModel = LibraryViewModel(fileManager: mockFileManager)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        mockFileManager = nil
        viewModel = nil
        try await super.tearDown()
    }

    /// 2. Make the test `async`
    func testDeleteBook() async throws {
        let book = Book(title: "Delete Me", format: "epub", filePath: "delete.epub", coverPath: "cover.jpg")
        context.insert(book)
        try context.save()

        let expectation = XCTestExpectation(description: "File removal called")
        expectation.expectedFulfillmentCount = 2

        // 3. `await` interaction with the actor
        await mockFileManager.setRemoveItemExpectation(expectation)

        viewModel.deleteBook(book, modelContext: context)

        // Verify DB deletion immediately
        let books = try context.fetch(FetchDescriptor<Book>())
        XCTAssertTrue(books.isEmpty)

        // Verify file deletion async using the modern concurrency await wrapper
        await fulfillment(of: [expectation], timeout: 2.0)

        // 4. `await` state checks on the actor
        let removed = await mockFileManager.removeItemCalled
        XCTAssertTrue(removed)
    }
}
