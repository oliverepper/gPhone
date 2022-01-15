//
//  gPhoneApp.swift
//  gPhone
//
//  Created by Oliver Epper on 13.01.22.
//

import SwiftUI

@main
struct gPhoneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.microSwitchClient)
        }
    }
}
