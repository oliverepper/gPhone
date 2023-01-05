//
//  AppDelegate.swift
//  gPhone
//
//  Created by Oliver Epper on 13.01.22.
//

import Foundation
import UIKit
import Combine

let invitationSubject = PassthroughSubject<UUID, Never>()

final class AppDelegate: NSObject, UIApplicationDelegate {
    let microSwitchClient = MicroSwitchClient()
    let notificationPermission = NotificationPermission()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UIApplication.shared.registerForRemoteNotifications()
        print("Done starting \(ProcessInfo.processInfo.processName)")

        notificationPermission.request()
        return true
    }
}

extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Reveiced Token: \(deviceToken)")
        microSwitchClient.addToken(token: deviceToken, for: UserDefaults.standard.string(forKey: MicroSwitchClient.Keys.handle.rawValue) ?? "Unknwon")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
}
