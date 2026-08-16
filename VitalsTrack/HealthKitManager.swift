import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {

    private let healthStore = HKHealthStore()

    // MARK: - Current values

    @Published var steps: Double = 0
    @Published var hrv: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var exerciseMinutes: Double = 0
    @Published var sleepHours: Double = 0


    // MARK: - Baselines

    @Published var baselineHRV: Double = 0
    @Published var baselineRestingHeartRate: Double = 0
    @Published var baselineSleepHours: Double = 0


    // MARK: - Readiness

    @Published var readiness: ReadinessResult?


    @Published var isAuthorized = false


    // MARK: - Authorization

    func requestAuthorization() async {

        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        guard
            let stepType = HKQuantityType.quantityType(
                forIdentifier: .stepCount
            ),

            let hrvType = HKQuantityType.quantityType(
                forIdentifier: .heartRateVariabilitySDNN
            ),

            let restingHRType = HKQuantityType.quantityType(
                forIdentifier: .restingHeartRate
            ),

            let heartRateType = HKQuantityType.quantityType(
                forIdentifier: .heartRate
            ),

            let activeEnergyType = HKQuantityType.quantityType(
                forIdentifier: .activeEnergyBurned
            ),

            let exerciseType = HKQuantityType.quantityType(
                forIdentifier: .appleExerciseTime
            ),

            let sleepType = HKCategoryType.categoryType(
                forIdentifier: .sleepAnalysis
            )

        else {
            return
        }


        let readTypes: Set<HKObjectType> = [
            stepType,
            hrvType,
            restingHRType,
            heartRateType,
            activeEnergyType,
            exerciseType,
            sleepType
        ]


        do {

            try await healthStore.requestAuthorization(
                toShare: [],
                read: readTypes
            )

            isAuthorized = true

            await refreshAllData()

        } catch {

            print(
                "HealthKit authorization failed:",
                error
            )
        }
    }


    // MARK: - Refresh Everything

    func refreshAllData() async {

        // Current values
        await fetchTodaySteps()
        await fetchLatestHRV()
        await fetchRestingHeartRate()
        await fetchLatestHeartRate()
        await fetchTodayActiveEnergy()
        await fetchTodayExerciseMinutes()
        await fetchLastNightSleep()

        // Baselines
        await fetchHRVBaseline()
        await fetchRestingHeartRateBaseline()
        await fetchSleepBaseline()

        calculateReadiness()
    }


    // MARK: - Readiness

    private func calculateReadiness() {

        guard
            hrv > 0,
            restingHeartRate > 0,
            sleepHours > 0,
            baselineHRV > 0,
            baselineRestingHeartRate > 0,
            baselineSleepHours > 0
        else {

            readiness = nil
            return
        }


        readiness = ReadinessEngine.calculate(
            currentHRV: hrv,
            baselineHRV: baselineHRV,

            currentRestingHeartRate:
                restingHeartRate,

            baselineRestingHeartRate:
                baselineRestingHeartRate,

            currentSleepHours:
                sleepHours,

            baselineSleepHours:
                baselineSleepHours
        )
    }


    // MARK: - Steps

    func fetchTodaySteps() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier: .stepCount
            )
        else {
            return
        }

        let startOfDay =
            Calendar.current.startOfDay(
                for: Date()
            )


        steps = await fetchCumulativeQuantity(
            type: type,
            start: startOfDay,
            end: Date(),
            unit: .count()
        )
    }


    // MARK: - Current HRV

    func fetchLatestHRV() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier:
                    .heartRateVariabilitySDNN
            )
        else {
            return
        }


        hrv = await fetchMostRecentQuantity(
            type: type,
            unit:
                HKUnit.secondUnit(
                    with: .milli
                )
        )
    }


    // MARK: - Current Resting HR

    func fetchRestingHeartRate() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier:
                    .restingHeartRate
            )
        else {
            return
        }


        restingHeartRate =
            await fetchMostRecentQuantity(
                type: type,

                unit:
                    HKUnit.count()
                        .unitDivided(
                            by: .minute()
                        )
            )
    }


    // MARK: - Current Heart Rate

    func fetchLatestHeartRate() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier: .heartRate
            )
        else {
            return
        }


        heartRate =
            await fetchMostRecentQuantity(
                type: type,

                unit:
                    HKUnit.count()
                        .unitDivided(
                            by: .minute()
                        )
            )
    }


    // MARK: - Active Energy

    func fetchTodayActiveEnergy() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier:
                    .activeEnergyBurned
            )
        else {
            return
        }


        let startOfDay =
            Calendar.current.startOfDay(
                for: Date()
            )


        activeEnergy =
            await fetchCumulativeQuantity(
                type: type,
                start: startOfDay,
                end: Date(),
                unit: .kilocalorie()
            )
    }


    // MARK: - Exercise

    func fetchTodayExerciseMinutes() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier:
                    .appleExerciseTime
            )
        else {
            return
        }


        let startOfDay =
            Calendar.current.startOfDay(
                for: Date()
            )


        exerciseMinutes =
            await fetchCumulativeQuantity(
                type: type,
                start: startOfDay,
                end: Date(),
                unit: .minute()
            )
    }


    // MARK: - Last Night Sleep

    func fetchLastNightSleep() async {

        sleepHours =
            await fetchSleepHours(
                start:
                    Calendar.current.date(
                        byAdding: .hour,
                        value: -24,
                        to: Date()
                    ) ?? Date(),

                end: Date()
            )
    }


    // MARK: - 7 Day HRV Baseline

    func fetchHRVBaseline() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier:
                    .heartRateVariabilitySDNN
            )
        else {
            return
        }


        let calendar = Calendar.current
        let now = Date()

        guard let start =
            calendar.date(
                byAdding: .day,
                value: -7,
                to: now
            )
        else {
            return
        }


        let values =
            await fetchQuantitySamples(
                type: type,
                start: start,
                end: now,
                unit:
                    HKUnit.secondUnit(
                        with: .milli
                    )
            )


        baselineHRV =
            average(
                values
            )
    }


    // MARK: - 7 Day Resting HR Baseline

    func fetchRestingHeartRateBaseline() async {

        guard let type =
            HKQuantityType.quantityType(
                forIdentifier:
                    .restingHeartRate
            )
        else {
            return
        }


        let calendar = Calendar.current
        let now = Date()

        guard let start =
            calendar.date(
                byAdding: .day,
                value: -7,
                to: now
            )
        else {
            return
        }


        let values =
            await fetchQuantitySamples(
                type: type,
                start: start,
                end: now,

                unit:
                    HKUnit.count()
                        .unitDivided(
                            by: .minute()
                        )
            )


        baselineRestingHeartRate =
            average(
                values
            )
    }


    // MARK: - 7 Day Sleep Baseline

    func fetchSleepBaseline() async {

        let calendar = Calendar.current
        let now = Date()

        var nightlyValues: [Double] = []


        for daysAgo in 1...7 {

            guard
                let end =
                    calendar.date(
                        byAdding: .day,
                        value: -(daysAgo - 1),
                        to: now
                    ),

                let start =
                    calendar.date(
                        byAdding: .hour,
                        value: -24,
                        to: end
                    )

            else {
                continue
            }


            let hours =
                await fetchSleepHours(
                    start: start,
                    end: end
                )


            if hours > 0 {

                nightlyValues.append(
                    hours
                )
            }
        }


        baselineSleepHours =
            average(
                nightlyValues
            )
    }


    // MARK: - Sleep Query

    private func fetchSleepHours(
        start: Date,
        end: Date
    ) async -> Double {

        guard let sleepType =
            HKCategoryType.categoryType(
                forIdentifier:
                    .sleepAnalysis
            )
        else {
            return 0
        }


        let predicate =
            HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictEndDate
            )


        let sortDescriptor =
            NSSortDescriptor(
                key:
                    HKSampleSortIdentifierStartDate,
                ascending: true
            )


        let hours: Double =
            await withCheckedContinuation {
                continuation in


                let query =
                    HKSampleQuery(
                        sampleType:
                            sleepType,

                        predicate:
                            predicate,

                        limit:
                            HKObjectQueryNoLimit,

                        sortDescriptors: [
                            sortDescriptor
                        ]
                    ) {
                        _,
                        samples,
                        error in


                        guard
                            error == nil,

                            let samples =
                                samples
                                as? [HKCategorySample]

                        else {

                            continuation.resume(
                                returning: 0
                            )

                            return
                        }


                        let asleepValues:
                            Set<Int> = [

                            HKCategoryValueSleepAnalysis
                                .asleepUnspecified
                                .rawValue,

                            HKCategoryValueSleepAnalysis
                                .asleepCore
                                .rawValue,

                            HKCategoryValueSleepAnalysis
                                .asleepDeep
                                .rawValue,

                            HKCategoryValueSleepAnalysis
                                .asleepREM
                                .rawValue
                        ]


                        let totalSeconds =
                            samples
                                .filter {

                                    asleepValues
                                        .contains(
                                            $0.value
                                        )
                                }

                                .reduce(
                                    0.0
                                ) {
                                    result,
                                    sample in

                                    result
                                    + sample
                                        .endDate
                                        .timeIntervalSince(
                                            sample
                                                .startDate
                                        )
                                }


                        continuation.resume(
                            returning:
                                totalSeconds
                                / 3600
                        )
                    }


                healthStore.execute(
                    query
                )
            }


        return hours
    }


    // MARK: - Historical Quantity Samples

    private func fetchQuantitySamples(
        type: HKQuantityType,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> [Double] {

        await withCheckedContinuation {
            continuation in


            let predicate =
                HKQuery.predicateForSamples(
                    withStart: start,
                    end: end,
                    options: .strictStartDate
                )


            let query =
                HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit:
                        HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) {
                    _,
                    samples,
                    error in


                    guard
                        error == nil,

                        let samples =
                            samples
                            as? [HKQuantitySample]

                    else {

                        continuation.resume(
                            returning: []
                        )

                        return
                    }


                    let values =
                        samples.map {

                            $0.quantity
                                .doubleValue(
                                    for: unit
                                )
                        }


                    continuation.resume(
                        returning:
                            values
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Cumulative Quantity

    private func fetchCumulativeQuantity(
        type: HKQuantityType,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async -> Double {

        await withCheckedContinuation {
            continuation in


            let predicate =
                HKQuery.predicateForSamples(
                    withStart: start,
                    end: end,
                    options:
                        .strictStartDate
                )


            let query =
                HKStatisticsQuery(
                    quantityType: type,

                    quantitySamplePredicate:
                        predicate,

                    options:
                        .cumulativeSum
                ) {
                    _,
                    result,
                    error in


                    guard error == nil else {

                        continuation.resume(
                            returning: 0
                        )

                        return
                    }


                    let value =
                        result?
                            .sumQuantity()?
                            .doubleValue(
                                for: unit
                            )
                        ?? 0


                    continuation.resume(
                        returning: value
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Most Recent Quantity

    private func fetchMostRecentQuantity(
        type: HKQuantityType,
        unit: HKUnit
    ) async -> Double {

        await withCheckedContinuation {
            continuation in


            let sortDescriptor =
                NSSortDescriptor(
                    key:
                        HKSampleSortIdentifierEndDate,

                    ascending:
                        false
                )


            let query =
                HKSampleQuery(
                    sampleType:
                        type,

                    predicate:
                        nil,

                    limit:
                        1,

                    sortDescriptors: [
                        sortDescriptor
                    ]
                ) {
                    _,
                    samples,
                    error in


                    guard
                        error == nil,

                        let sample =
                            samples?
                                .first
                            as?
                                HKQuantitySample

                    else {

                        continuation.resume(
                            returning: 0
                        )

                        return
                    }


                    let value =
                        sample.quantity
                            .doubleValue(
                                for: unit
                            )


                    continuation.resume(
                        returning:
                            value
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Average

    private func average(
        _ values: [Double]
    ) -> Double {

        guard !values.isEmpty else {
            return 0
        }


        return
            values.reduce(
                0,
                +
            )
            / Double(
                values.count
            )
    }
}
