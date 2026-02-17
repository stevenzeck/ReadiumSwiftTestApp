//
//  ReadiumService.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

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

    /// Opener for publications
    let publicationOpener: PublicationOpener

    // MARK: - Initialization

    /// Initializes the Readium service and its dependencies.
    init() {
        httpClient = DefaultHTTPClient()
        assetRetriever = AssetRetriever(httpClient: httpClient)
        server = GCDHTTPServer(assetRetriever: assetRetriever)
        publicationOpener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            )
        )
    }

    // MARK: - Public Methods

    /// Opens a publication from a local or remote URL using the shared AssetRetriever and PublicationOpener.
    ///
    /// - Parameters:
    ///   - url: The file URL or remote URL of the publication.
    ///   - sender: The sender (optional), used for user interaction callbacks if needed.
    /// - Returns: A fully parsed `Publication`.
    func openPublication(at url: URL) async throws -> (Publication, Format) {
        guard let absoluteURL = AnyURL(url: url).absoluteURL else {
            throw PublicationError.invalidURL
        }
        let asset = try await assetRetriever.retrieve(url: absoluteURL).get()

        let publication = try await publicationOpener.open(asset: asset, allowUserInteraction: false).get()

        return (publication, asset.format)
    }
}
