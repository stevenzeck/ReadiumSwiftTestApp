//
//  TestHelper.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/4/26.
//

import Foundation
@testable import ReadiumSwiftTestApp
import SwiftData

class TestHelper {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Book.self,
            OPDSFeed.self,
            Bookmark.self,
            Highlight.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
