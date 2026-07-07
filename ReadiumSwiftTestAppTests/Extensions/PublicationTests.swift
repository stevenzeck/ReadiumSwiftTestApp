//
//  PublicationTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

@Suite(.serialized) @MainActor
struct PublicationTests {
    @Test func downloadLinkDetection() {
        // Case 1: Standard OPDS acquisition
        let link1 = Link(href: "book.epub", rels: ["http://opds-spec.org/acquisition"])
        let pub1 = Publication(manifest: Manifest(metadata: Metadata(title: "T"), links: [link1]))
        #expect(pub1.downloadLink?.href == "book.epub")

        // Case 2: Generic enclosure
        let link2 = Link(href: "audio.mp3", rels: ["enclosure"])
        let pub2 = Publication(manifest: Manifest(metadata: Metadata(title: "T"), links: [link2]))
        #expect(pub2.downloadLink?.href == "audio.mp3")

        // Case 3: Priority (First detection)
        let link3a = Link(href: "ignore.html", rels: ["search"])
        let link3b = Link(href: "real.epub", rels: ["http://opds-spec.org/acquisition"])
        let pub3 = Publication(manifest: Manifest(metadata: Metadata(title: "T"), links: [link3a, link3b]))
        #expect(pub3.downloadLink?.href == "real.epub")

        // Case 4: None
        let link4 = Link(href: "preview.html", rels: ["preview"])
        let pub4 = Publication(manifest: Manifest(metadata: Metadata(title: "T"), links: [link4]))
        #expect(pub4.downloadLink == nil)
    }

    @Test func coverURLDetection() {
        // Case 1: In 'images' collection (OPDS 2)
        let imgLink = Link(href: "cover.jpg")
        let pub1 = Publication(
            manifest: Manifest(
                metadata: Metadata(title: "T"),
                subcollections: ["images": [PublicationCollection(links: [imgLink])]]
            )
        )

        #expect(pub1.coverURL?.absoluteString == "cover.jpg")

        // Case 2: In 'links' with rel (OPDS 1)
        let relLink = Link(href: "cover-rel.jpg", rels: ["http://opds-spec.org/image"])
        let pub2 = Publication(manifest: Manifest(metadata: Metadata(title: "T"), links: [relLink]))
        #expect(pub2.coverURL?.absoluteString == "cover-rel.jpg")
    }
}
