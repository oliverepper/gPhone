//
//  NotificationPermissionDelegate.swift
//  gPhone
//
//  Created by Oliver Epper on 14.01.22.
//

import Foundation
import UserNotifications
import Combine
import UIKit

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard
            let base64 = response.notification.request.content.userInfo["payload"] as? String,
            let data = Data(base64Encoded: base64),
            let payload = try? JSONDecoder().decode(SessionID.self, from: data) else {
                completionHandler()
                return
            }

        invitationSubject.send(payload.value)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard let base64 = notification.request.content.userInfo["payload"] as? String,
              let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode(SessionID.self, from: data) else {
                  completionHandler(.sound)
                  return
              }

        invitationSubject.send(payload.value)
        completionHandler(.sound)
    }
}
