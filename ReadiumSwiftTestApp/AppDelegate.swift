//
//  AppDelegate.swift
//  ReadiumSwiftTestApp
//
//  Created by Steven Zeck on 2/10/26.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Store the completion handler provided by the system
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(_: UIApplication, handleEventsForBackgroundURLSession _: String, completionHandler: @escaping () -> Void) {
        // Store the handler to be called when the download service finishes processing events
        backgroundSessionCompletionHandler = completionHandler
    }
}
