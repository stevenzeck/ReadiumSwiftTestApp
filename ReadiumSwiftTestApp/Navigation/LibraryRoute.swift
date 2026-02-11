//
//  LibraryRoute.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/10/26.
//

import Foundation
import ReadiumShared

/// Defines the navigation paths for the Library Tab
enum LibraryRoute: Hashable {
    case reader(Book)
    case fileImport
    case urlImport
}

/// Defines the navigation paths for the OPDS Tab
enum OPDSRoute: Hashable {
    case feedBrowser(url: URL, title: String)
    case publicationDetail(Publication)
}
