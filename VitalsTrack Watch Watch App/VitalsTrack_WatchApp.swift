//
//  VitalsTrack_WatchApp.swift
//  VitalsTrack Watch Watch App
//
//  Created by Helena Douglas on 15/08/2026.
//

import SwiftUI
import WatchKit


@main
struct VitalsTrack_Watch_Watch_AppApp: App {

    private let healthBackgroundManager =
        HealthBackgroundManager()


    var body: some Scene {

        WindowGroup {

            ContentView()
                .onOpenURL { url in

                    guard
                        url.scheme == "zevli",
                        url.host == "metric"
                    else {
                        return
                    }


                    let metric =
                        url.pathComponents
                            .filter {
                                $0 != "/"
                            }
                            .first


                    guard
                        let metric
                    else {
                        return
                    }


                    NotificationCenter.default.post(
                        name: .zevliMetricDeepLink,
                        object: metric
                    )
                }
                .task {

                    await healthBackgroundManager
                        .start()
                }
        }
        .backgroundTask(
            .appRefresh(
                HealthBackgroundManager
                    .backgroundRefreshIdentifier
            )
        ) {

            await healthBackgroundManager
                .handleBackgroundRefresh()
        }
    }
}
