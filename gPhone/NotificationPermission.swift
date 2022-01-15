//
//  Hugo.swift
//  gPhone
//
//  Created by Oliver Epper on 14.01.22.
//

import Foundation
import UserNotifications
import UIKit

struct SessionID: Codable {
    let value: UUID
}

final class NotificationPermission: NSObject, ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private var notificationDelegate = NotificationDelegate()

    override init() {
        super.init()

        UNUserNotificationCenter.current().delegate = self.notificationDelegate

        self.update()
    }

    func request() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (_, error) in
            if let error = error {
                print(error.localizedDescription)
            }

            self.update()
        }
    }

    private func update() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
}
