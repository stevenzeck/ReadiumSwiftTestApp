//
//  OPDSFeedListViewModel.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/8/26.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
class OPDSFeedListViewModel {
    var showingAddFeed = false
    var feedToEdit: OPDSFeed?

    var feedsToDelete: [OPDSFeed] = []
    var showingDeleteAlert = false

    /// Prepares deletion by identifying the feeds and showing the alert.
    func requestDeletion(at offsets: IndexSet, in feeds: [OPDSFeed]) {
        feedsToDelete = offsets.map { feeds[$0] }
        if !feedsToDelete.isEmpty {
            showingDeleteAlert = true
        }
    }

    func confirmDeletion(modelContext: ModelContext) {
        for feed in feedsToDelete {
            modelContext.delete(feed)
        }
        feedsToDelete = []
    }
}
