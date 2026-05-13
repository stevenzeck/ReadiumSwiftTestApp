# ReadiumSwiftTestApp

A SwiftUI iOS application using the Readium Swift Toolkit to browse OPDS feeds, download books, and read them.

## Prerequisites

*   **Xcode 15+** (Recommended: Xcode 16.2 as per Readium 3.6.0 requirements)
*   **iOS 17.0+**

## Setup Instructions

1.  **Open the Project:**
    *   Open the folder containing `Package.swift` in Xcode.
    *   Xcode will resolve the Swift Package dependencies (Readium Swift Toolkit). This might take a few minutes.

2.  **Configuration:**
    *   **Signing:** You will need to select your Development Team in the project settings (Targets -> ReadiumSwiftTestApp -> Signing & Capabilities).
    *   **Capabilities:**
        *   **Background Modes:** Enable "Background fetch" and "Background processing" (or "Downloads") if you want robust background downloading, though the basic `URLSession` implementation provided works for standard downloads.
        *   **File Access:** The app saves files to the Documents directory.
    *   **App Transport Security (ATS):**
        *   If you plan to use OPDS feeds via HTTP (not HTTPS), you must configure `Info.plist`. Since this is a Swift Package based project, you might need to create an `Info.plist` manually if you convert it to an Xcode Project, or configure it in the Target Info tab.
        *   Add `App Transport Security Settings` -> `Allow Arbitrary Loads` = `YES`.

3.  **Run:**
    *   Select the **ReadiumSwiftTestApp** scheme (or generic iOS Device / Simulator).
    *   Build and Run (Cmd+R).

## Features

*   **Library:**
    *   View downloaded books with covers.
    *   Import EPUB/PDF files from the device (Files app).
    *   Import via direct URL.
    *   Tap a book to read.
    *   Long press to delete a book.
*   **OPDS:**
    *   Manage OPDS feeds (Add/Edit/Remove).
    *   Browse feeds (supports OPDS 1.x and 2.0).
    *   Download publications (supports Background downloads).

## Architecture

*   **UI:** SwiftUI
*   **Data:** SwiftData (Persists `Book` and `OPDSFeed` models).
*   **Readium Integration:**
    *   `ReadiumService`: Manages the Readium `AssetRetriever` and `PublicationOpener`.
    *   `ReaderView`: Wraps `EPUBNavigatorViewController` and `PDFNavigatorViewController` using `UIViewControllerRepresentable`.
    *   `OPDSBrowserView`: Uses `ReadiumOPDS` to parse feeds.

## Troubleshooting

*   **Compilation Errors:**
    *   If you see errors related to `ReadiumStreamer` initialization or `Navigator` creation, it might be due to API changes in the specific version of Readium loaded. The code uses standard APIs corresponding to Readium 3.x. Check the [Readium Swift Toolkit Documentation](https://github.com/readium/swift-toolkit) for latest signatures.
*   **Runtime Issues:**
    *   Ensure the "App Transport Security" settings allow arbitrary loads if you are connecting to HTTP OPDS feeds.
