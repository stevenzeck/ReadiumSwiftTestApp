//
//  ReadiumDTOs.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/8/26.
//

import Foundation
import ReadiumShared

/// A Sendable, codable struct representation of a Readium Locator.
/// Use this when passing location data between Actors, persisting data, or in ViewModels.
struct SendableLocator: Codable, Equatable, Hashable {
    let href: String
    let type: String
    let title: String?
    let locations: LocationsDTO
    let text: TextDTO

    /// Initialize from the Readium Class
    init(locator: Locator) {
        href = locator.href.string
        type = locator.mediaType.string
        title = locator.title
        locations = LocationsDTO(locations: locator.locations)
        text = TextDTO(text: locator.text)
    }

    /// Convert back to Readium class
    var toReadiumLocator: Locator {
        return Locator(
            href: AnyURL(string: href)!,
            mediaType: MediaType(type) ?? .html,
            title: title,
            locations: locations.toReadiumLocations,
            text: text.toReadiumText
        )
    }
}

struct LocationsDTO: Codable, Equatable, Hashable {
    let fragments: [String]
    let progression: Double?
    let position: Int?
    let totalProgression: Double?

    init(locations: Locator.Locations) {
        fragments = locations.fragments
        progression = locations.progression
        position = locations.position
        totalProgression = locations.totalProgression
    }

    var toReadiumLocations: Locator.Locations {
        return Locator.Locations(
            fragments: fragments,
            progression: progression,
            totalProgression: totalProgression,
            position: position
        )
    }
}

struct TextDTO: Codable, Equatable, Hashable {
    let after: String?
    let before: String?
    let highlight: String?

    init(text: Locator.Text) {
        after = text.after
        before = text.before
        highlight = text.highlight
    }

    var toReadiumText: Locator.Text {
        return Locator.Text(
            after: after,
            before: before,
            highlight: highlight
        )
    }
}
