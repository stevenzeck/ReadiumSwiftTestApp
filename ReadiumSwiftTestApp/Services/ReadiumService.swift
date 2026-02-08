//
//  ReadiumService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

import Combine
import Foundation
@preconcurrency import ReadiumAdapterGCDWebServer
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumStreamer
import SwiftUI

/// A centralized service for managing the Readium Toolkit's core components.
///
/// This service handles the lifecycle of the local HTTP server and the asset retriever,
/// which are required to open and render publications.
@Observable
@MainActor
class ReadiumService {
    // MARK: - Properties

    /// The HTTP server instance used to serve publication resources.
    ///
    /// Readium uses a local server to serve expanded EPUB assets to the WebView navigator.
    let server: GCDHTTPServer

    /// The retriever responsible for fetching and identifying publication assets.
    let assetRetriever: AssetRetriever

    /// The HTTP client used for network requests.
    let httpClient: HTTPClient

    // MARK: - Initialization

    /// Initializes the Readium service and its dependencies.
    init() {
        httpClient = DefaultHTTPClient()
        assetRetriever = AssetRetriever(httpClient: httpClient)
        server = GCDHTTPServer(assetRetriever: assetRetriever)
    }
}
