//
//  Publication+Extensions.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/5/26.
//

import Foundation
import ReadiumShared

extension Publication {
    /// Finds the first link with an acquisition or enclosure relation.
    var downloadLink: Link? {
        links.first(where: { link in
            link.rels.contains { rel in
                rel.hasPrefix("http://opds-spec.org/acquisition") || rel == "enclosure"
            }
        })
    }

    /// Finds the cover image URL from the publication's images or links.
    var coverURL: URL? {
        let link = images.first ?? links.first(where: {
            $0.rels.contains("cover") || $0.rels.contains("http://opds-spec.org/image")
        })

        guard let href = link?.href else { return nil }
        return URL(string: href)
    }
}
