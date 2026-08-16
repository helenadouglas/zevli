//
//  HealthBackgroundManager.swift
//  VitalsTrack
//
//  Created by Helena Douglas on 16/08/2026.
//

import Foundation
import HealthKit


final class HealthBackgroundManager {

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


        // Start observer queries immediately.
        // HealthKit can then wake the app when matching
        // health samples are added or changed.
        startObserverQueries()


        // Register the HealthKit types for background delivery.
        await enableBackgroundDelivery()


        // Always create a fresh snapshot when the Watch app
        // itself launches.
        await healthProvider
            .refreshSharedSnapshot()
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
