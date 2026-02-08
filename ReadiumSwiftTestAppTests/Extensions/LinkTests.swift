//
//  LinkTests.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/6/26.
//

import ReadiumShared
@testable import ReadiumSwiftTestApp
import XCTest

final class LinkTests: XCTestCase {
    func testOutlineChildren() {
        // Case 1: No children
        let linkNoChildren = Link(href: "chap1")
        XCTAssertNil(linkNoChildren.outlineChildren)

        // Case 2: With children
        let child = Link(href: "chap1-1")
        let linkWithChildren = Link(href: "chap1", children: [child])

        XCTAssertNotNil(linkWithChildren.outlineChildren)
        XCTAssertEqual(linkWithChildren.outlineChildren?.count, 1)
        XCTAssertEqual(linkWithChildren.outlineChildren?.first?.href, "chap1-1")
    }
}
