//
//  VitalsTrack_WatchApp.swift
//  VitalsTrack Watch Watch App
//
//  Created by Helena Douglas on 15/08/2026.
//

import SwiftUI


@main
struct VitalsTrack_Watch_Watch_AppApp: App {

    private let healthBackgroundManager =
        HealthBackgroundManager()


    var body: some Scene {

        WindowGroup {

            ContentView()
                .task {

                    await healthBackgroundManager
                        .start()
                }
        }
    }
}
