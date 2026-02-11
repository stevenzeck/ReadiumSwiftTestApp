//
//  Publication+Hashable.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/10/26.
//

import Foundation
import ReadiumShared

extension Publication: @retroactive Hashable {
    public static func == (lhs: Publication, rhs: Publication) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
