//
//  HealthBackgroundManager.swift
//  VitalsTrack
//
//  Created by Helena Douglas on 16/08/2026.
//

import Foundation
import HealthKit
import WatchKit


final class HealthBackgroundManager {

    static let backgroundRefreshIdentifier =
        "zevli.health.refresh"


    private let healthStore =
        HKHealthStore()


    private let healthProvider =
        WatchHealthDataProvider()


    private var observerQueries:
        [HKObserverQuery] = []


    private var hasStarted =
        false


    // MARK: - Start

    func start() async {

        guard !hasStarted else {
            return
        }


        hasStarted = true


        guard
            HKHealthStore
                .isHealthDataAvailable()
        else {
            return
        }


        print(
            "Starting Zevli HealthKit background manager"
        )


        // Start HealthKit observers as early as possible.
        startObserverQueries()


        // Enable background HealthKit delivery.
        await enableBackgroundDelivery()


        // Refresh immediately whenever Zevli launches.
        await healthProvider
            .refreshSharedSnapshot()


        // Ask watchOS for another opportunity to refresh
        // in roughly 15 minutes.
        scheduleNextBackgroundRefresh()
    }


    // MARK: - Scheduled Background Refresh

    func handleBackgroundRefresh() async {

        print(
            "Zevli scheduled background refresh started"
        )


        await healthProvider
            .refreshSharedSnapshot()


        print(
            "Zevli scheduled background refresh finished"
        )


        // Every background run requests the next one.
        scheduleNextBackgroundRefresh()
    }


    // MARK: - Schedule Next Refresh

    private func scheduleNextBackgroundRefresh() {

        let preferredDate =
            Date().addingTimeInterval(
                15 * 60
            )


        WKApplication.shared()
            .scheduleBackgroundRefresh(
                withPreferredDate:
                    preferredDate,

                userInfo:
                    Self
                        .backgroundRefreshIdentifier
                        as NSString
            ) {
                error in


                if let error {

                    print(
                        "Failed to schedule Zevli background refresh:",
                        error.localizedDescription
                    )

                } else {

                    print(
                        "Zevli background refresh requested for:",
                        preferredDate
                    )
                }
            }
    }


    // MARK: - Background Delivery

    private func enableBackgroundDelivery() async {

        let types =
            observedTypes()


        for type in types {

            do {

                try await healthStore
                    .enableBackgroundDelivery(
                        for: type,
                        frequency: .immediate
                    )


                print(
                    "Background delivery enabled:",
                    type.identifier
                )

            } catch {

                print(
                    "Failed background delivery:",
                    type.identifier,
                    error
                )
            }
        }
    }


    // MARK: - Observer Queries

    private func startObserverQueries() {

        let types =
            observedTypes()


        for type in types {

            let query =
                HKObserverQuery(
                    sampleType: type,
                    predicate: nil
                ) {
                    [weak self]
                    _,
                    completionHandler,
                    error in


                    if let error {

                        print(
                            "Health observer error:",
                            error
                        )


                        completionHandler()

                        return
                    }


                    print(
                        "HealthKit background change:",
                        type.identifier
                    )


                    Task {

                        await self?
                            .healthProvider
                            .refreshSharedSnapshot()


                        completionHandler()
                    }
                }


            observerQueries.append(
                query
            )


            healthStore.execute(
                query
            )


            print(
                "Health observer started:",
                type.identifier
            )
        }
    }


    // MARK: - Types To Observe

    private func observedTypes()
        -> [HKSampleType] {

        var types:
            [HKSampleType] = []


        if let steps =
            HKQuantityType.quantityType(
                forIdentifier:
                    .stepCount
            ) {

            types.append(
                steps
            )
        }


        if let activeEnergy =
            HKQuantityType.quantityType(
                forIdentifier:
                    .activeEnergyBurned
            ) {

            types.append(
                activeEnergy
            )
        }


        if let exercise =
            HKQuantityType.quantityType(
                forIdentifier:
                    .appleExerciseTime
            ) {

            types.append(
                exercise
            )
        }


        if let stand =
            HKCategoryType.categoryType(
                forIdentifier:
                    .appleStandHour
            ) {

            types.append(
                stand
            )
        }


        if let sleep =
            HKCategoryType.categoryType(
                forIdentifier:
                    .sleepAnalysis
            ) {

            types.append(
                sleep
            )
        }


        if let hrv =
            HKQuantityType.quantityType(
                forIdentifier:
                    .heartRateVariabilitySDNN
            ) {

            types.append(
                hrv
            )
        }


        if let restingHR =
            HKQuantityType.quantityType(
                forIdentifier:
                    .restingHeartRate
            ) {

            types.append(
                restingHR
            )
        }


        if let heartRate =
            HKQuantityType.quantityType(
                forIdentifier:
                    .heartRate
            ) {

            types.append(
                heartRate
            )
        }


        return types
    }
}
