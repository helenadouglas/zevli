//
//  HealthBackgroundManager.swift
//  VitalsTrack
//
//  Created by Helena Douglas on 16/08/2026.
//

import Foundation
import HealthKit


final class HealthBackgroundManager {

    private let healthStore = HKHealthStore()

    private let healthProvider =
        WatchHealthDataProvider()

    private var observerQueries:
        [HKObserverQuery] = []


    // MARK: - Start

    func start() async {

        guard
            HKHealthStore.isHealthDataAvailable()
        else {
            return
        }


        await enableBackgroundDelivery()
        startObserverQueries()
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
