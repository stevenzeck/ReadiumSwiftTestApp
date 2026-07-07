//
//  LinkTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

import Foundation
import ReadiumShared
@testable import ReadiumSwiftTestApp
import Testing

@Suite(.serialized) @MainActor
struct LinkTests {
    @Test func outlineChildren() {
        // Case 1: No children
        let linkNoChildren = Link(href: "chap1")
        #expect(linkNoChildren.outlineChildren == nil)

        // Case 2: With children
        let child = Link(href: "chap1-1")
        let linkWithChildren = Link(href: "chap1", children: [child])

        #expect(linkWithChildren.outlineChildren != nil)
        #expect(linkWithChildren.outlineChildren?.count == 1)
        #expect(linkWithChildren.outlineChildren?.first?.href == "chap1-1")
    }
}
