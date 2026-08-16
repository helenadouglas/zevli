import Foundation
import HealthKit
import WidgetKit


final class WatchHealthDataProvider {

    private let healthStore = HKHealthStore()


    // MARK: - Internal Sleep Models

    private struct SleepNight {

        let startDate: Date
        let endDate: Date

        let sleepHours: Double

        let awakeMinutes: Double
        let interruptionCount: Int
    }


    private struct SleepBucket {

        var asleepIntervals: [DateInterval] = []
        var awakeIntervals: [DateInterval] = []
    }


    private struct SleepScoreBreakdown {

        let durationPoints: Double
        let interruptionPoints: Double

        var total: Double {

            let rawTotal =
                durationPoints
                + interruptionPoints

            return min(
                max(
                    rawTotal / 70 * 100,
                    0
                ),
                100
            )
        }
    }


    // MARK: - Activity Goals

    private struct ActivityGoals {

        let moveGoal: Double
        let exerciseGoal: Double
        let standGoal: Double
    }


    // MARK: - Refresh Shared Snapshot

    func refreshSharedSnapshot() async {

        let authorized =
            await requestAuthorization()


        guard authorized else {

            print(
                "HealthKit authorization failed"
            )

            return
        }


        async let stepsTask =
            todaySteps()

        async let energyTask =
            todayActiveEnergy()

        async let exerciseTask =
            todayExerciseMinutes()

        async let standTask =
            todayStandHours()

        async let activityGoalsTask =
            todayActivityGoals()

        async let sleepHistoryTask =
            fetchSleepNights()

        async let hrvTask =
            latestHRV()

        async let restingHRTask =
            latestRestingHeartRate()

        async let heartRateTask =
            latestHeartRate()


        let (
            steps,
            activeEnergy,
            exerciseMinutes,
            standHours,
            activityGoals,
            sleepNights,
            hrv,
            restingHeartRate,
            heartRate
        ) = await (
            stepsTask,
            energyTask,
            exerciseTask,
            standTask,
            activityGoalsTask,
            sleepHistoryTask,
            hrvTask,
            restingHRTask,
            heartRateTask
        )


        let moveGoal =
            activityGoals?.moveGoal
            ?? 300


        let exerciseGoal =
            activityGoals?.exerciseGoal
            ?? 30


        let standGoal =
            activityGoals?.standGoal
            ?? 10


        let currentNight =
            sleepNights.first


        let sleepHours =
            currentNight?
                .sleepHours
            ?? 0


        let sleepBreakdown =
            calculateSleepScore(
                currentNight:
                    currentNight
            )


        let sleepScore =
            sleepBreakdown.total


        async let baselineHRVTask =
            sevenDayAverage(
                identifier:
                    .heartRateVariabilitySDNN,

                unit:
                    HKUnit.secondUnit(
                        with: .milli
                    )
            )


        async let baselineRestingHRTask =
            sevenDayAverage(
                identifier:
                    .restingHeartRate,

                unit:
                    HKUnit.count()
                        .unitDivided(
                            by: .minute()
                        )
            )


        let (
            baselineHRV,
            baselineRestingHR
        ) = await (
            baselineHRVTask,
            baselineRestingHRTask
        )


        let readiness =
            calculateReadiness(
                hrv: hrv,

                baselineHRV:
                    baselineHRV,

                restingHR:
                    restingHeartRate,

                baselineRestingHR:
                    baselineRestingHR,

                sleepScore:
                    sleepScore
            )


        let activity =
            calculateActivity(
                steps: steps,
                energy: activeEnergy,
                exercise: exerciseMinutes
            )


        let strain =
            min(
                activeEnergy
                / max(moveGoal, 1)
                * 100,
                100
            )


        let snapshot =
            SharedHealthSnapshot(
                updatedAt: .now,

                sleepHours:
                    sleepHours,

                sleepScore:
                    sleepScore,

                readiness:
                    readiness,

                activity:
                    activity,

                hrv:
                    hrv,

                restingHeartRate:
                    restingHeartRate,

                heartRate:
                    heartRate,

                steps:
                    steps,

                activeEnergy:
                    activeEnergy,

                exerciseMinutes:
                    exerciseMinutes,

                standHours:
                    standHours,

                moveGoal:
                    moveGoal,

                exerciseGoal:
                    exerciseGoal,

                standGoal:
                    standGoal,

                recovery:
                    readiness,

                strain:
                    strain
            )


        SharedHealthStore.save(
            snapshot
        )


        WidgetCenter.shared
            .reloadTimelines(
                ofKind:
                    SharedHealthStore
                        .widgetKind
            )


        print(
            "Saved Watch health snapshot:"
        )

        print(
            "Sleep hours:",
            sleepHours
        )

        print(
            "Sleep duration points:",
            sleepBreakdown.durationPoints
        )

        print(
            "Sleep interruption points:",
            sleepBreakdown.interruptionPoints
        )

        print(
            "Sleep Score:",
            sleepScore
        )

        print(
            "Steps:",
            steps
        )

        print(
            "HRV:",
            hrv
        )

        print(
            "Resting HR:",
            restingHeartRate
        )

        print(
            "Heart Rate:",
            heartRate
        )

        print(
            "Energy:",
            activeEnergy
        )

        print(
            "Exercise:",
            exerciseMinutes
        )

        print(
            "Stand:",
            standHours
        )

        print(
            "Move goal:",
            moveGoal
        )

        print(
            "Exercise goal:",
            exerciseGoal
        )

        print(
            "Stand goal:",
            standGoal
        )

        print(
            "Readiness:",
            readiness
        )
    }


    // MARK: - Authorization

    private func requestAuthorization()
        async -> Bool {

        guard
            HKHealthStore
                .isHealthDataAvailable()
        else {

            return false
        }


        guard
            let stepType =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .stepCount
                ),

            let activeEnergyType =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .activeEnergyBurned
                ),

            let exerciseType =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .appleExerciseTime
                ),

            let standType =
                HKCategoryType.categoryType(
                    forIdentifier:
                        .appleStandHour
                ),

            let sleepType =
                HKCategoryType.categoryType(
                    forIdentifier:
                        .sleepAnalysis
                ),

            let hrvType =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .heartRateVariabilitySDNN
                ),

            let restingHRType =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .restingHeartRate
                ),

            let heartRateType =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .heartRate
                )

        else {

            return false
        }


        let readTypes:
            Set<HKObjectType> = [

                stepType,
                activeEnergyType,
                exerciseType,
                standType,
                sleepType,
                hrvType,
                restingHRType,
                heartRateType,
                HKObjectType.activitySummaryType()
            ]


        do {

            try await healthStore
                .requestAuthorization(
                    toShare: [],
                    read: readTypes
                )


            return true


        } catch {

            print(
                "HealthKit authorization error:",
                error
            )


            return false
        }
    }


    // MARK: - Activity Goal Query

    private func todayActivityGoals()
        async -> ActivityGoals? {

        let calendar =
            Calendar.current


            var components =
                calendar.dateComponents(
                    [
                        .era,
                        .year,
                        .month,
                        .day
                    ],
                    from: Date()
                )

            components.calendar = calendar
            components.timeZone = calendar.timeZone


        let predicate =
            HKQuery.predicateForActivitySummary(
                with: components
            )


        return await withCheckedContinuation {
            continuation in


            let query =
                HKActivitySummaryQuery(
                    predicate: predicate
                ) {
                    _,
                    summaries,
                    error in


                    guard
                        error == nil,
                        let summary =
                            summaries?.first
                    else {

                        continuation.resume(
                            returning: nil
                        )

                        return
                    }


                    let moveGoal =
                        summary
                            .activeEnergyBurnedGoal
                            .doubleValue(
                                for:
                                    .kilocalorie()
                            )


                    let exerciseGoal =
                        summary
                            .appleExerciseTimeGoal
                            .doubleValue(
                                for:
                                    .minute()
                            )


                    let standGoal =
                        summary
                            .appleStandHoursGoal
                            .doubleValue(
                                for:
                                    .count()
                            )


                    continuation.resume(
                        returning:
                            ActivityGoals(
                                moveGoal:
                                    moveGoal,

                                exerciseGoal:
                                    exerciseGoal,

                                standGoal:
                                    standGoal
                            )
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Sleep History

    private func fetchSleepNights()
        async -> [SleepNight] {

        guard
            let sleepType =
                HKCategoryType.categoryType(
                    forIdentifier:
                        .sleepAnalysis
                )
        else {

            return []
        }


        let now =
            Date()


        guard
            let start =
                Calendar.current.date(
                    byAdding: .day,
                    value: -16,
                    to: now
                )
        else {

            return []
        }


        let predicate =
            HKQuery.predicateForSamples(
                withStart: start,
                end: now,
                options: []
            )


        return await withCheckedContinuation {
            continuation in


            let query =
                HKSampleQuery(
                    sampleType:
                        sleepType,

                    predicate:
                        predicate,

                    limit:
                        HKObjectQueryNoLimit,

                    sortDescriptors:
                        nil
                ) {
                    [weak self]
                    _,
                    samples,
                    error in


                    guard
                        error == nil,

                        let samples =
                            samples
                            as? [HKCategorySample],

                        let self

                    else {

                        continuation.resume(
                            returning: []
                        )

                        return
                    }


                    let nights =
                        self.buildSleepNights(
                            from:
                                samples
                        )


                    continuation.resume(
                        returning:
                            nights
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Build Nights

    private func buildSleepNights(
        from samples:
            [HKCategorySample]
    ) -> [SleepNight] {

        let calendar =
            Calendar.current


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


        let awakeValue =
            HKCategoryValueSleepAnalysis
                .awake
                .rawValue


        var buckets:
            [Date: SleepBucket] = [:]


        for sample in samples {

            guard
                asleepValues.contains(
                    sample.value
                )
                ||
                sample.value == awakeValue
            else {

                continue
            }


            let shiftedDate =
                calendar.date(
                    byAdding: .hour,
                    value: -12,
                    to: sample.endDate
                )
                ?? sample.endDate


            let key =
                calendar.startOfDay(
                    for:
                        shiftedDate
                )


            let interval =
                DateInterval(
                    start:
                        sample.startDate,

                    end:
                        sample.endDate
                )


            var bucket =
                buckets[key]
                ?? SleepBucket()


            if asleepValues.contains(
                sample.value
            ) {

                bucket
                    .asleepIntervals
                    .append(
                        interval
                    )

            } else {

                bucket
                    .awakeIntervals
                    .append(
                        interval
                    )
            }


            buckets[key] =
                bucket
        }


        var nights:
            [SleepNight] = []


        for bucket in buckets.values {

            let asleep =
                mergeIntervals(
                    bucket
                        .asleepIntervals
                )


            guard
                let sleepStart =
                    asleep
                        .first?
                        .start,

                let sleepEnd =
                    asleep
                        .last?
                        .end
            else {

                continue
            }


            let totalAsleepSeconds =
                asleep.reduce(
                    0.0
                ) {
                    partial,
                    interval in

                    partial
                    + interval.duration
                }


            let sleepHours =
                totalAsleepSeconds
                / 3600


            guard
                sleepHours >= 2
            else {

                continue
            }


            let clippedAwake =
                bucket
                    .awakeIntervals
                    .compactMap {
                        interval
                        -> DateInterval? in


                        let start =
                            Swift.max(
                                interval.start,
                                sleepStart
                            )


                        let end =
                            Swift.min(
                                interval.end,
                                sleepEnd
                            )


                        guard
                            end > start
                        else {

                            return nil
                        }


                        return DateInterval(
                            start: start,
                            end: end
                        )
                    }


            let mergedAwake =
                mergeIntervals(
                    clippedAwake
                )


            let awakeMinutes =
                mergedAwake.reduce(
                    0.0
                ) {
                    partial,
                    interval in

                    partial
                    + interval.duration
                    / 60
                }


            let interruptionCount =
                mergedAwake.filter {

                    $0.duration >= 120
                }
                .count


            nights.append(
                SleepNight(
                    startDate:
                        sleepStart,

                    endDate:
                        sleepEnd,

                    sleepHours:
                        sleepHours,

                    awakeMinutes:
                        awakeMinutes,

                    interruptionCount:
                        interruptionCount
                )
            )
        }


        return nights
            .sorted {

                $0.endDate
                >
                $1.endDate
            }
    }


    // MARK: - Merge Intervals

    private func mergeIntervals(
        _ intervals:
            [DateInterval]
    ) -> [DateInterval] {

        let sorted =
            intervals.sorted {

                $0.start
                <
                $1.start
            }


        guard
            var current =
                sorted.first
        else {

            return []
        }


        var result:
            [DateInterval] = []


        for interval
            in sorted.dropFirst() {

            if interval.start
                <= current.end {

                current =
                    DateInterval(
                        start:
                            current.start,

                        end:
                            Swift.max(
                                current.end,
                                interval.end
                            )
                    )

            } else {

                result.append(
                    current
                )

                current =
                    interval
            }
        }


        result.append(
            current
        )


        return result
    }


    // MARK: - Sleep Score

    private func calculateSleepScore(
        currentNight:
            SleepNight?
    ) -> SleepScoreBreakdown {

        guard
            let currentNight
        else {

            return SleepScoreBreakdown(
                durationPoints: 0,
                interruptionPoints: 0
            )
        }


        let durationPoints =
            sleepDurationPoints(
                hours:
                    currentNight
                        .sleepHours
            )


        let interruptionPoints =
            sleepInterruptionPoints(
                awakeMinutes:
                    currentNight
                        .awakeMinutes,

                interruptionCount:
                    currentNight
                        .interruptionCount
            )


        return SleepScoreBreakdown(
            durationPoints:
                durationPoints,

            interruptionPoints:
                interruptionPoints
        )
    }


    // MARK: - Duration — max 50

    private func sleepDurationPoints(
        hours: Double
    ) -> Double {

        if hours >= 8 {

            return 50
        }


        if hours >= 7 {

            return
                43
                + (
                    hours - 7
                )
                * 7
        }


        if hours >= 6 {

            return
                33
                + (
                    hours - 6
                )
                * 10
        }


        if hours >= 5 {

            return
                22
                + (
                    hours - 5
                )
                * 11
        }


        if hours >= 4 {

            return
                12
                + (
                    hours - 4
                )
                * 10
        }


        return max(
            hours / 4
            * 12,
            0
        )
    }


    // MARK: - Interruptions — max 20

    private func sleepInterruptionPoints(
        awakeMinutes: Double,
        interruptionCount: Int
    ) -> Double {

        let awakeTimePoints:
            Double


        switch awakeMinutes {

        case ...5:
            awakeTimePoints = 20

        case ...10:
            awakeTimePoints = 19

        case ...15:
            awakeTimePoints = 18

        case ...20:
            awakeTimePoints = 16

        case ...30:
            awakeTimePoints = 14

        case ...40:
            awakeTimePoints = 11

        case ...50:
            awakeTimePoints = 8

        case ...60:
            awakeTimePoints = 6

        case ...75:
            awakeTimePoints = 3

        case ...90:
            awakeTimePoints = 1

        default:
            awakeTimePoints = 0
        }


        let extraWakeUps =
            max(
                interruptionCount - 2,
                0
            )


        let wakePenalty =
            Double(
                extraWakeUps
            )
            * 1.25


        return min(
            max(
                awakeTimePoints
                - wakePenalty,
                0
            ),
            20
        )
    }


    // MARK: - Steps

    private func todaySteps()
        async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .stepCount
                )
        else {

            return 0
        }


        return await cumulativeToday(
            type: type,
            unit: .count()
        )
    }


    // MARK: - Active Energy

    private func todayActiveEnergy()
        async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .activeEnergyBurned
                )
        else {

            return 0
        }


        return await cumulativeToday(
            type: type,
            unit: .kilocalorie()
        )
    }


    // MARK: - Exercise

    private func todayExerciseMinutes()
        async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .appleExerciseTime
                )
        else {

            return 0
        }


        return await cumulativeToday(
            type: type,
            unit: .minute()
        )
    }


    // MARK: - Stand

    private func todayStandHours()
        async -> Double {

        guard
            let type =
                HKCategoryType.categoryType(
                    forIdentifier:
                        .appleStandHour
                )
        else {

            return 0
        }


        let start =
            Calendar.current
                .startOfDay(
                    for:
                        Date()
                )


        let predicate =
            HKQuery.predicateForSamples(
                withStart:
                    start,

                end:
                    Date(),

                options:
                    .strictStartDate
            )


        return await withCheckedContinuation {
            continuation in


            let query =
                HKSampleQuery(
                    sampleType:
                        type,

                    predicate:
                        predicate,

                    limit:
                        HKObjectQueryNoLimit,

                    sortDescriptors:
                        nil
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


                    let count =
                        samples.filter {

                            $0.value
                            ==
                            HKCategoryValueAppleStandHour
                                .stood
                                .rawValue
                        }
                        .count


                    continuation.resume(
                        returning:
                            Double(
                                count
                            )
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - HRV

    private func latestHRV()
        async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .heartRateVariabilitySDNN
                )
        else {

            return 0
        }


        return await mostRecent(
            type: type,

            unit:
                HKUnit.secondUnit(
                    with:
                        .milli
                )
        )
    }


    // MARK: - Resting Heart Rate

    private func latestRestingHeartRate()
        async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .restingHeartRate
                )
        else {

            return 0
        }


        return await mostRecent(
            type: type,

            unit:
                HKUnit.count()
                    .unitDivided(
                        by:
                            .minute()
                    )
        )
    }


    // MARK: - Heart Rate

    private func latestHeartRate()
        async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .heartRate
                )
        else {

            return 0
        }


        return await mostRecent(
            type: type,

            unit:
                HKUnit.count()
                    .unitDivided(
                        by:
                            .minute()
                    )
        )
    }


    // MARK: - Today Quantity

    private func cumulativeToday(
        type: HKQuantityType,
        unit: HKUnit
    ) async -> Double {

        let start =
            Calendar.current
                .startOfDay(
                    for:
                        Date()
                )


        let predicate =
            HKQuery.predicateForSamples(
                withStart:
                    start,

                end:
                    Date(),

                options:
                    .strictStartDate
            )


        return await withCheckedContinuation {
            continuation in


            let query =
                HKStatisticsQuery(
                    quantityType:
                        type,

                    quantitySamplePredicate:
                        predicate,

                    options:
                        .cumulativeSum
                ) {
                    _,
                    result,
                    error in


                    guard
                        error == nil
                    else {

                        continuation.resume(
                            returning: 0
                        )

                        return
                    }


                    let value =
                        result?
                            .sumQuantity()?
                            .doubleValue(
                                for:
                                    unit
                            )
                        ?? 0


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


    // MARK: - Most Recent Quantity

    private func mostRecent(
        type: HKQuantityType,
        unit: HKUnit
    ) async -> Double {

        let sort =
            NSSortDescriptor(
                key:
                    HKSampleSortIdentifierEndDate,

                ascending:
                    false
            )


        return await withCheckedContinuation {
            continuation in


            let query =
                HKSampleQuery(
                    sampleType:
                        type,

                    predicate:
                        nil,

                    limit:
                        1,

                    sortDescriptors: [
                        sort
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
                            as? HKQuantitySample
                    else {

                        continuation.resume(
                            returning: 0
                        )

                        return
                    }


                    continuation.resume(
                        returning:
                            sample.quantity
                                .doubleValue(
                                    for:
                                        unit
                                )
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Seven-Day Average

    private func sevenDayAverage(
        identifier:
            HKQuantityTypeIdentifier,

        unit:
            HKUnit
    ) async -> Double {

        guard
            let type =
                HKQuantityType.quantityType(
                    forIdentifier:
                        identifier
                )
        else {

            return 0
        }


        guard
            let start =
                Calendar.current.date(
                    byAdding:
                        .day,

                    value:
                        -7,

                    to:
                        Date()
                )
        else {

            return 0
        }


        let predicate =
            HKQuery.predicateForSamples(
                withStart:
                    start,

                end:
                    Date(),

                options:
                    .strictStartDate
            )


        return await withCheckedContinuation {
            continuation in


            let query =
                HKSampleQuery(
                    sampleType:
                        type,

                    predicate:
                        predicate,

                    limit:
                        HKObjectQueryNoLimit,

                    sortDescriptors:
                        nil
                ) {
                    _,
                    samples,
                    error in


                    guard
                        error == nil,

                        let samples =
                            samples
                            as? [HKQuantitySample],

                        !samples.isEmpty
                    else {

                        continuation.resume(
                            returning: 0
                        )

                        return
                    }


                    let values =
                        samples.map {

                            $0.quantity
                                .doubleValue(
                                    for:
                                        unit
                                )
                        }


                    let average =
                        values.reduce(
                            0,
                            +
                        )
                        /
                        Double(
                            values.count
                        )


                    continuation.resume(
                        returning:
                            average
                    )
                }


            healthStore.execute(
                query
            )
        }
    }


    // MARK: - Readiness

    private func calculateReadiness(
        hrv: Double,

        baselineHRV: Double,

        restingHR: Double,

        baselineRestingHR:
            Double,

        sleepScore: Double
    ) -> Double {

        guard
            hrv > 0,
            baselineHRV > 0,
            restingHR > 0,
            baselineRestingHR > 0,
            sleepScore > 0
        else {

            return 0
        }


        let hrvScore =
            normalizedScore(
                ratio:
                    hrv
                    / baselineHRV,

                good:
                    1.05,

                bad:
                    0.75
            )


        let restingScore =
            normalizedScore(
                ratio:
                    baselineRestingHR
                    / restingHR,

                good:
                    1.05,

                bad:
                    0.80
            )


        return min(
            max(
                hrvScore
                * 0.45

                + restingScore
                * 0.25

                + sleepScore
                * 0.30,

                0
            ),
            100
        )
    }


    // MARK: - Activity

    private func calculateActivity(
        steps: Double,
        energy: Double,
        exercise: Double
    ) -> Double {

        let stepScore =
            min(
                steps
                / 10_000,
                1
            )


        let energyScore =
            min(
                energy
                / 500,
                1
            )


        let exerciseScore =
            min(
                exercise
                / 30,
                1
            )


        return (
            stepScore
            * 0.40

            + energyScore
            * 0.35

            + exerciseScore
            * 0.25
        )
        * 100
    }


    // MARK: - Normalize

    private func normalizedScore(
        ratio: Double,
        good: Double,
        bad: Double
    ) -> Double {

        if ratio >= good {

            return 100
        }


        if ratio <= bad {

            return 20
        }


        let progress =
            (
                ratio
                - bad
            )
            /
            (
                good
                - bad
            )


        return
            20
            + progress
            * 80
    }
}
