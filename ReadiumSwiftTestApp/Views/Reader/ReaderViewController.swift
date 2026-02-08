//
//  ReaderViewController.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 12/30/25.
//

@preconcurrency import ReadiumNavigator
@preconcurrency import ReadiumShared
import UIKit

/// A container view controller that wraps the Readium Navigator.
///
/// This controller acts as a responder chain target for custom menu actions like "Highlight".
/// Since `UIMenuController` (or `UIEditMenuInteraction`) walks the responder chain to find
/// actions, this parent controller intercepts the custom selectors defined in `ReaderView`.
class ReaderViewController: UIViewController {
    // MARK: - Properties

    /// The actual Readium navigator (EPUB or PDF) being displayed.
    var childNavigator: UIViewController?

    /// Callback when user triggers a highlight action.
    ///
    /// - Parameters:
    ///   - selection: The current text selection.
    ///   - color: The color string (e.g., "yellow", "red").
    var onHighlight: ((Selection, String) -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if let child = childNavigator {
            addChild(child)
            view.addSubview(child.view)
            child.view.frame = view.bounds
            child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            child.didMove(toParent: self)
        }
    }

    // MARK: - Helpers

    /// Retrieves the current selection from the child navigator.
    private func getSelection() -> Selection? {
        return (childNavigator as? SelectableNavigator)?.currentSelection
    }

    // MARK: - Color Actions

    // These methods are targeted by the selectors in `EditingAction`.

    @objc func highlightYellow(_: Any?) {
        guard let selection = getSelection() else { return }
        onHighlight?(selection, "yellow")
    }

    @objc func highlightGreen(_: Any?) {
        guard let selection = getSelection() else { return }
        onHighlight?(selection, "green")
    }

    @objc func highlightRed(_: Any?) {
        guard let selection = getSelection() else { return }
        onHighlight?(selection, "red")
    }

    @objc func highlightBlue(_: Any?) {
        guard let selection = getSelection() else { return }
        onHighlight?(selection, "blue")
    }

    @objc func highlightPurple(_: Any?) {
        guard let selection = getSelection() else { return }
        onHighlight?(selection, "purple")
    }
}
