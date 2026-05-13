//
//  ReaderView.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import SwiftData
import SwiftUI
import UIKit

/// A SwiftUI wrapper for Readium's UIKit-based Navigators.
///
/// Wraps `EPUBNavigatorViewController` (and `PDFNavigatorViewController` if available)
/// via `UIViewControllerRepresentable`.
struct ReaderView: UIViewControllerRepresentable {
    // MARK: - Properties

    /// The Readium publication to display.
    let publication: Publication

    /// The local book entity.
    let book: Book

    /// Binding to control the visibility of the navigation bars (chrome).
    @Binding var isChromeVisible: Bool

    /// Target location to navigate to. Set this to trigger navigation.
    @Binding var targetLocator: Locator?

    /// The initial location to go to.
    let initialLocation: Locator?

    /// Callback when navigator is created, to setup preferences.
    var onGetNavigator: ((Navigator) -> Void)?

    /// Callback for text selection highlight action (Selection, Color).
    var onHighlight: ((Selection, String) -> Void)?

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate, EPUBNavigatorDelegate, PDFNavigatorDelegate {
        var parent: ReaderView

        init(_ parent: ReaderView) {
            self.parent = parent
        }

        /// Handles tap gestures to toggle UI chrome visibility.
        ///
        /// Taps in the center 60% of the screen toggle the chrome; other taps are ignored
        /// (likely page turns handled by the navigator).
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }

            let point = gesture.location(in: view)
            let viewSize = view.bounds.size

            // Define center zone (middle 60% of screen width)
            let centerZoneX = viewSize.width * 0.2
            let centerZoneWidth = viewSize.width * 0.6

            let isCenterTap = point.x >= centerZoneX && point.x <= (centerZoneX + centerZoneWidth)

            if isCenterTap {
                Task { @MainActor in
                    withAnimation {
                        self.parent.isChromeVisible.toggle()
                    }
                }
            }
        }

        /// Allow gesture to work alongside Readium's internal gestures (e.g. text selection, links)
        func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
            return true
        }

        @MainActor
        func navigator(_: Navigator, locationDidChange locator: Locator) {
            // Update the book model
            parent.book.lastReadLocationJSON = try? locator.jsonString()

            // Explicitly save to persist immediately
            try? parent.modelContext.save()
        }

        /// Handle jump to error (optional but recommended)
        func navigator(_: Navigator, didJumpTo locator: Locator) {
            parent.book.lastReadLocationJSON = try? locator.jsonString()
            try? parent.modelContext.save()
        }

        @MainActor
        func navigator(_: Navigator, presentError error: NavigatorError) {
            print("Navigator error: \(error.localizedDescription)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIViewController {
        var navigatorVC: UIViewController?
        var navigatorInstance: Navigator?

        if publication.conforms(to: .epub) {
            do {
                var config = EPUBNavigatorViewController.Configuration()

                // Register Color Actions
                // Note: UIMenuItem typically displays text. Emojis are text.
                config.editingActions.append(contentsOf: [
                    EditingAction(title: "🟡", action: #selector(ReaderViewController.highlightYellow(_:))),
                    EditingAction(title: "🟢", action: #selector(ReaderViewController.highlightGreen(_:))),
                    EditingAction(title: "🔴", action: #selector(ReaderViewController.highlightRed(_:))),
                    EditingAction(title: "🔵", action: #selector(ReaderViewController.highlightBlue(_:))),
                    EditingAction(title: "🟣", action: #selector(ReaderViewController.highlightPurple(_:))),
                ])

                let epubNavigator = try EPUBNavigatorViewController(
                    publication: publication,
                    initialLocation: initialLocation,
                    config: config
                )
                epubNavigator.delegate = context.coordinator
                navigatorVC = epubNavigator
                navigatorInstance = epubNavigator
            } catch {
                return makeErrorVC(error.localizedDescription)
            }
        } else if publication.conforms(to: .pdf) {
            do {
                let pdfNavigator = try PDFNavigatorViewController(
                    publication: publication,
                    initialLocation: initialLocation
                )
                pdfNavigator.delegate = context.coordinator
                navigatorVC = pdfNavigator
                navigatorInstance = pdfNavigator
            } catch {
                return makeErrorVC(error.localizedDescription)
            }
        } else {
            return makeErrorVC("Format not supported")
        }

        // Wrap in ReaderViewController to handle menu actions via responder chain
        if let navigatorVC = navigatorVC {
            let readerVC = ReaderViewController()
            readerVC.childNavigator = navigatorVC
            readerVC.onHighlight = onHighlight

            // Attach gesture recognizer to the navigator view (which is inside readerVC)
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            tapGesture.delegate = context.coordinator
            tapGesture.numberOfTapsRequired = 1
            tapGesture.cancelsTouchesInView = false
            navigatorVC.view.addGestureRecognizer(tapGesture)

            if let navigatorInstance = navigatorInstance {
                Task { @MainActor in
                    onGetNavigator?(navigatorInstance)
                }
            }
            return readerVC
        }
        return makeErrorVC("Unknown Error")
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
        // uiViewController is ReaderViewController (or error VC)
        guard let readerVC = uiViewController as? ReaderViewController else { return }

        // Update callback closure in case state changed
        readerVC.onHighlight = onHighlight

        // Handle programmatic navigation request
        if let locator = targetLocator {
            if let navigator = readerVC.childNavigator as? Navigator {
                // Perform navigation
                Task {
                    await navigator.go(to: locator)
                }
                // Reset the binding on the main thread to prevent loops
                Task { @MainActor in
                    self.targetLocator = nil
                }
            }
        }
    }

    /// Helper to create a simple error view controller.
    ///
    /// - Parameter message: The error message to display.
    /// - Returns: A UIViewController displaying the message centered in red text.
    private func makeErrorVC(_ message: String) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .white
        let label = UILabel()
        label.text = message
        label.textColor = .red
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        ])
        return vc
    }
}
