import SwiftUI
import HealthKit
import Combine


// MARK: - Cache Models

private struct CachedDashboardSnapshot: Codable {

    let savedAt: Date

    let steps: Double
    let activeEnergy: Double

    let hrv: Double
    let restingHeartRate: Double
    let heartRate: Double

    let sleepDetails: CachedSleepDetailsSnapshot
}


private struct CachedSleepDetailsSnapshot: Codable {

    let totalHours: Double

    let remHours: Double
    let coreHours: Double
    let deepHours: Double

    let awakeMinutes: Double
    let interruptionCount: Int

    let startDate: Date?
    let endDate: Date?
}


// MARK: - Sleep Models

struct SleepDetailsSnapshot {

    var totalHours: Double = 0

    var remHours: Double = 0
    var coreHours: Double = 0
    var deepHours: Double = 0

    var awakeMinutes: Double = 0

    var interruptionCount: Int = 0

    var startDate: Date?
    var endDate: Date?


    var sleepScore: Double {

        guard totalHours > 0 else {
            return 0
        }

        let duration =
            durationPoints(
                hours: totalHours
            )

        let interruptions =
            interruptionPoints(
                awakeMinutes: awakeMinutes,
                interruptionCount: interruptionCount
            )

        return min(
            max(
                (
                    duration
                    + interruptions
                )
                / 70
                * 100,
                0
            ),
            100
        )
    }


    private func durationPoints(
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
            hours / 4 * 12,
            0
        )
    }


    private func interruptionPoints(
        awakeMinutes: Double,
        interruptionCount: Int
    ) -> Double {

        let awakePoints: Double

        switch awakeMinutes {

        case ...5:
            awakePoints = 20

        case ...10:
            awakePoints = 19

        case ...15:
            awakePoints = 18

        case ...20:
            awakePoints = 16

        case ...30:
            awakePoints = 14

        case ...40:
            awakePoints = 11

        case ...50:
            awakePoints = 8

        case ...60:
            awakePoints = 6

        case ...75:
            awakePoints = 3

        case ...90:
            awakePoints = 1

        default:
            awakePoints = 0
        }


        let extraWakeUps =
            max(
                interruptionCount - 2,
                0
            )


        let penalty =
            Double(extraWakeUps)
            * 1.25


        return min(
            max(
                awakePoints - penalty,
                0
            ),
            20
        )
    }
}


// MARK: - Readiness Model

struct ReadinessBreakdown {

    let hrvPoints: Double
    let restingHRPoints: Double
    let sleepPoints: Double


    var total: Double {

        min(
            max(
                hrvPoints
                + restingHRPoints
                + sleepPoints,
                0
            ),
            100
        )
    }
}


// MARK: - Health Store

@MainActor
final class HealthDashboardStore: ObservableObject {

    private let healthStore =
        HKHealthStore()


    private let cacheKey =
        "VitalsTrack.dashboardSnapshot"


    private var didCheckAuthorization =
        false


    @Published var steps: Double = 0
    @Published var activeEnergy: Double = 0

    @Published var hrv: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var heartRate: Double = 0

    @Published var sleepDetails =
        SleepDetailsSnapshot()

    @Published var isLoading =
        false

    @Published var errorMessage:
        String?


    init() {

        loadCachedSnapshot()
    }


    var sleepHours: Double {

        sleepDetails.totalHours
    }


    var readinessBreakdown:
        ReadinessBreakdown {

        let hrvPoints: Double = {

            guard hrv > 0 else {
                return 0
            }

            return min(
                max(
                    hrv / 100,
                    0
                ),
                1
            )
            * 45
        }()


        let restingHRPoints: Double = {

            guard restingHeartRate > 0 else {
                return 0
            }

            let normalized =
                min(
                    max(
                        (
                            90
                            - restingHeartRate
                        )
                        / 40,
                        0
                    ),
                    1
                )

            return normalized * 25
        }()


        let sleepPoints: Double = {

            guard
                sleepDetails.sleepScore > 0
            else {
                return 0
            }

            return min(
                max(
                    sleepDetails.sleepScore
                    / 100,
                    0
                ),
                1
            )
            * 30
        }()


        return ReadinessBreakdown(
            hrvPoints:
                hrvPoints,

            restingHRPoints:
                restingHRPoints,

            sleepPoints:
                sleepPoints
        )
    }


    var simpleVibeScore: Int {

        Int(
            readinessBreakdown
                .total
                .rounded()
        )
    }


    // MARK: - Refresh

    func refresh() async {

        isLoading = true
        errorMessage = nil


        do {

            if !didCheckAuthorization {

                try await
                    requestAuthorizationIfNeeded()

                didCheckAuthorization =
                    true
            }


            async let stepsValue =
                todayCumulative(
                    identifier:
                        .stepCount,

                    unit:
                        .count()
                )


            async let energyValue =
                todayCumulative(
                    identifier:
                        .activeEnergyBurned,

                    unit:
                        .kilocalorie()
                )


            async let hrvValue =
                latestQuantity(
                    identifier:
                        .heartRateVariabilitySDNN,

                    unit:
                        HKUnit.secondUnit(
                            with: .milli
                        )
                )


            async let restingValue =
                latestQuantity(
                    identifier:
                        .restingHeartRate,

                    unit:
                        HKUnit.count()
                            .unitDivided(
                                by: .minute()
                            )
                )


            async let heartValue =
                latestQuantity(
                    identifier:
                        .heartRate,

                    unit:
                        HKUnit.count()
                            .unitDivided(
                                by: .minute()
                            )
                )


            async let sleepValue =
                fetchSleepDetails()


            let (
                newSteps,
                newEnergy,
                newHRV,
                newResting,
                newHeart,
                newSleep
            ) = await (
                stepsValue,
                energyValue,
                hrvValue,
                restingValue,
                heartValue,
                sleepValue
            )


            steps =
                newSteps

            activeEnergy =
                newEnergy

            hrv =
                newHRV

            restingHeartRate =
                newResting

            heartRate =
                newHeart

            sleepDetails =
                newSleep


            saveCachedSnapshot()

        } catch {

            errorMessage =
                error.localizedDescription
        }


        isLoading = false
    }


    // MARK: - Authorization

    private func requestAuthorizationIfNeeded()
        async throws {

        guard
            HKHealthStore
                .isHealthDataAvailable()
        else {
            return
        }


        guard
            let steps =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .stepCount
                ),

            let energy =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .activeEnergyBurned
                ),

            let hrv =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .heartRateVariabilitySDNN
                ),

            let resting =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .restingHeartRate
                ),

            let heart =
                HKQuantityType.quantityType(
                    forIdentifier:
                        .heartRate
                ),

            let sleep =
                HKCategoryType.categoryType(
                    forIdentifier:
                        .sleepAnalysis
                )

        else {
            return
        }


        let readTypes:
            Set<HKObjectType> = [

                steps,
                energy,
                hrv,
                resting,
                heart,
                sleep
            ]


        let status =
            try await healthStore
                .statusForAuthorizationRequest(
                    toShare: [],
                    read: readTypes
                )


        if status == .shouldRequest {

            try await healthStore
                .requestAuthorization(
                    toShare: [],
                    read: readTypes
                )
        }
    }


    // MARK: - Today Cumulative

    private func todayCumulative(
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


        let start =
            Calendar.current
                .startOfDay(
                    for: Date()
                )


        let predicate =
            HKQuery.predicateForSamples(
                withStart: start,
                end: Date(),
                options:
                    .strictStartDate
            )


        return await
            withCheckedContinuation {
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
                        _ in


                        let value =
                            result?
                                .sumQuantity()?
                                .doubleValue(
                                    for: unit
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


    // MARK: - Latest Quantity

    private func latestQuantity(
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


        let sort =
            NSSortDescriptor(
                key:
                    HKSampleSortIdentifierEndDate,

                ascending:
                    false
            )


        return await
            withCheckedContinuation {
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
                        _ in


                        guard
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


                        continuation.resume(
                            returning:
                                sample.quantity
                                    .doubleValue(
                                        for: unit
                                    )
                        )
                    }


                healthStore.execute(
                    query
                )
            }
    }


    // MARK: - Sleep Details

    private func fetchSleepDetails()
        async -> SleepDetailsSnapshot {

        guard
            let type =
                HKCategoryType.categoryType(
                    forIdentifier:
                        .sleepAnalysis
                )
        else {

            return SleepDetailsSnapshot()
        }


        let now =
            Date()


        guard
            let start =
                Calendar.current.date(
                    byAdding:
                        .hour,

                    value:
                        -24,

                    to:
                        now
                )
        else {

            return SleepDetailsSnapshot()
        }


        let predicate =
            HKQuery.predicateForSamples(
                withStart:
                    start,

                end:
                    now,

                options: []
            )


        return await
            withCheckedContinuation {
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
                        _ in


                        guard
                            let samples =
                                samples
                                as?
                                [HKCategorySample]
                        else {

                            continuation.resume(
                                returning:
                                    SleepDetailsSnapshot()
                            )

                            return
                        }


                        let sleepSamples =
                            samples.filter {

                                $0.value
                                ==
                                HKCategoryValueSleepAnalysis
                                    .asleepUnspecified
                                    .rawValue

                                ||

                                $0.value
                                ==
                                HKCategoryValueSleepAnalysis
                                    .asleepCore
                                    .rawValue

                                ||

                                $0.value
                                ==
                                HKCategoryValueSleepAnalysis
                                    .asleepDeep
                                    .rawValue

                                ||

                                $0.value
                                ==
                                HKCategoryValueSleepAnalysis
                                    .asleepREM
                                    .rawValue
                            }


                        guard
                            let sleepStart =
                                sleepSamples
                                    .map(
                                        \.startDate
                                    )
                                    .min(),

                            let sleepEnd =
                                sleepSamples
                                    .map(
                                        \.endDate
                                    )
                                    .max()
                        else {

                            continuation.resume(
                                returning:
                                    SleepDetailsSnapshot()
                            )

                            return
                        }


                        func duration(
                            for value: Int
                        ) -> Double {

                            samples
                                .filter {
                                    $0.value == value
                                }
                                .reduce(
                                    0
                                ) {
                                    total,
                                    sample in

                                    total
                                    + sample.endDate
                                        .timeIntervalSince(
                                            sample.startDate
                                        )
                                }
                        }


                        let unspecifiedSeconds =
                            duration(
                                for:
                                    HKCategoryValueSleepAnalysis
                                        .asleepUnspecified
                                        .rawValue
                            )


                        let coreSeconds =
                            duration(
                                for:
                                    HKCategoryValueSleepAnalysis
                                        .asleepCore
                                        .rawValue
                            )


                        let deepSeconds =
                            duration(
                                for:
                                    HKCategoryValueSleepAnalysis
                                        .asleepDeep
                                        .rawValue
                            )


                        let remSeconds =
                            duration(
                                for:
                                    HKCategoryValueSleepAnalysis
                                        .asleepREM
                                        .rawValue
                            )


                        let totalSleepSeconds =
                            unspecifiedSeconds
                            + coreSeconds
                            + deepSeconds
                            + remSeconds


                        let awakeSamples =
                            samples.filter {

                                $0.value
                                ==
                                HKCategoryValueSleepAnalysis
                                    .awake
                                    .rawValue

                                &&

                                $0.endDate
                                > sleepStart

                                &&

                                $0.startDate
                                < sleepEnd
                            }


                        let awakeSeconds =
                            awakeSamples
                                .reduce(
                                    0
                                ) {
                                    total,
                                    sample in

                                    let clippedStart =
                                        max(
                                            sample.startDate,
                                            sleepStart
                                        )


                                    let clippedEnd =
                                        min(
                                            sample.endDate,
                                            sleepEnd
                                        )


                                    guard
                                        clippedEnd
                                        > clippedStart
                                    else {

                                        return total
                                    }


                                    return
                                        total
                                        + clippedEnd
                                            .timeIntervalSince(
                                                clippedStart
                                            )
                                }


                        let interruptionCount =
                            awakeSamples
                                .filter {

                                    $0.endDate
                                        .timeIntervalSince(
                                            $0.startDate
                                        )
                                    >= 120
                                }
                                .count


                        let result =
                            SleepDetailsSnapshot(
                                totalHours:
                                    totalSleepSeconds
                                    / 3600,

                                remHours:
                                    remSeconds
                                    / 3600,

                                coreHours:
                                    coreSeconds
                                    / 3600,

                                deepHours:
                                    deepSeconds
                                    / 3600,

                                awakeMinutes:
                                    awakeSeconds
                                    / 60,

                                interruptionCount:
                                    interruptionCount,

                                startDate:
                                    sleepStart,

                                endDate:
                                    sleepEnd
                            )


                        continuation.resume(
                            returning:
                                result
                        )
                    }


                healthStore.execute(
                    query
                )
            }
    }


    // MARK: - Cache

    private func loadCachedSnapshot() {

        guard
            let data =
                UserDefaults.standard.data(
                    forKey: cacheKey
                ),

            let cached =
                try? JSONDecoder().decode(
                    CachedDashboardSnapshot.self,
                    from: data
                )

        else {
            return
        }


        steps =
            cached.steps

        activeEnergy =
            cached.activeEnergy

        hrv =
            cached.hrv

        restingHeartRate =
            cached.restingHeartRate

        heartRate =
            cached.heartRate


        sleepDetails =
            SleepDetailsSnapshot(
                totalHours:
                    cached.sleepDetails.totalHours,

                remHours:
                    cached.sleepDetails.remHours,

                coreHours:
                    cached.sleepDetails.coreHours,

                deepHours:
                    cached.sleepDetails.deepHours,

                awakeMinutes:
                    cached.sleepDetails.awakeMinutes,

                interruptionCount:
                    cached.sleepDetails.interruptionCount,

                startDate:
                    cached.sleepDetails.startDate,

                endDate:
                    cached.sleepDetails.endDate
            )
    }


    private func saveCachedSnapshot() {

        let cached =
            CachedDashboardSnapshot(
                savedAt:
                    Date(),

                steps:
                    steps,

                activeEnergy:
                    activeEnergy,

                hrv:
                    hrv,

                restingHeartRate:
                    restingHeartRate,

                heartRate:
                    heartRate,

                sleepDetails:
                    CachedSleepDetailsSnapshot(
                        totalHours:
                            sleepDetails.totalHours,

                        remHours:
                            sleepDetails.remHours,

                        coreHours:
                            sleepDetails.coreHours,

                        deepHours:
                            sleepDetails.deepHours,

                        awakeMinutes:
                            sleepDetails.awakeMinutes,

                        interruptionCount:
                            sleepDetails.interruptionCount,

                        startDate:
                            sleepDetails.startDate,

                        endDate:
                            sleepDetails.endDate
                    )
            )


        guard
            let data =
                try? JSONEncoder().encode(
                    cached
                )
        else {
            return
        }


        UserDefaults.standard.set(
            data,
            forKey: cacheKey
        )
    }
}


// MARK: - Theme

private enum VitalsTheme {

    static let background =
        Color(
            red: 0.97,
            green: 0.96,
            blue: 0.94
        )


    static let card =
        Color.white.opacity(
            0.82
        )


    static let accent =
        Color(
            red: 0.48,
            green: 0.37,
            blue: 0.78
        )


    static let accentSoft =
        Color(
            red: 0.90,
            green: 0.87,
            blue: 0.97
        )
}


// MARK: - Root

struct ContentView: View {

    @StateObject
    private var health =
        HealthDashboardStore()


    @State
    private var hasFinishedInitialLoad =
        false


    var body: some View {

        Group {

            if hasFinishedInitialLoad {

                TabView {

                    TodayDashboardView(
                        health: health
                    )
                    .tabItem {

                        Label(
                            "Today",
                            systemImage:
                                "sparkles"
                        )
                    }


                    InsightsView(
                        health: health
                    )
                    .tabItem {

                        Label(
                            "Insights",
                            systemImage:
                                "lightbulb"
                        )
                    }
                }
                .tint(
                    VitalsTheme.accent
                )

            } else {

                VitalsLoadingView()
            }
        }
        .task {

            await health.refresh()


            withAnimation(
                .easeInOut(
                    duration: 0.25
                )
            ) {

                hasFinishedInitialLoad =
                    true
            }
        }
    }
}


// MARK: - Loading Screen

struct VitalsLoadingView: View {

    var body: some View {

        ZStack {

            VitalsTheme.background
                .ignoresSafeArea()


            VStack(
                spacing: 18
            ) {

                ZStack {

                    Circle()
                        .fill(
                            VitalsTheme.accentSoft
                        )
                        .frame(
                            width: 74,
                            height: 74
                        )


                    Image(
                        systemName:
                            "heart"
                    )
                    .font(
                        .system(
                            size: 30,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        VitalsTheme.accent
                    )


                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 11,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        VitalsTheme.accent
                    )
                    .offset(
                        x: 22,
                        y: -22
                    )
                }


                VStack(
                    spacing: 5
                ) {

                    Text(
                        "Zevli"
                    )
                    .font(
                        .title3
                            .weight(
                                .semibold
                            )
                    )


                    Text(
                        "Updating your health data"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                ProgressView()
                    .tint(
                        VitalsTheme.accent
                    )
            }
        }
    }
}


// MARK: - Today

struct TodayDashboardView: View {

    @ObservedObject
    var health:
        HealthDashboardStore


    var body: some View {

        NavigationStack {

            ZStack {

                VitalsTheme.background
                    .ignoresSafeArea()


                ScrollView {

                    VStack(
                        spacing: 16
                    ) {

                        DailyVibeCard(
                            score:
                                health.simpleVibeScore
                        )


                        ReadinessBreakdownCard(
                            breakdown:
                                health.readinessBreakdown
                        )


                        DailyCheckInCard()


                        LazyVGrid(
                            columns: [

                                GridItem(
                                    .flexible()
                                ),

                                GridItem(
                                    .flexible()
                                )
                            ],

                            spacing:
                                12
                        ) {

                            NavigationLink {

                                SleepDetailsView(
                                    details:
                                        health.sleepDetails
                                )

                            } label: {

                                SleepMetricCard(
                                    value:
                                        String(
                                            format:
                                                "%.1f h",

                                            health.sleepHours
                                        )
                                )
                            }
                            .buttonStyle(
                                .plain
                            )


                            MetricCard(
                                title:
                                    "HRV",

                                value:
                                    "\(Int(health.hrv)) ms",

                                icon:
                                    "waveform.path.ecg"
                            )


                            MetricCard(
                                title:
                                    "Resting HR",

                                value:
                                    "\(Int(health.restingHeartRate)) bpm",

                                icon:
                                    "heart.fill"
                            )


                            MetricCard(
                                title:
                                    "Heart Rate",

                                value:
                                    "\(Int(health.heartRate)) bpm",

                                icon:
                                    "heart.text.square.fill"
                            )


                            MetricCard(
                                title:
                                    "Steps",

                                value:
                                    health.steps
                                        .formatted(
                                            .number
                                                .precision(
                                                    .fractionLength(
                                                        0
                                                    )
                                                )
                                        ),

                                icon:
                                    "shoeprints.fill"
                            )


                            MetricCard(
                                title:
                                    "Active Energy",

                                value:
                                    "\(Int(health.activeEnergy)) kcal",

                                icon:
                                    "flame.fill"
                            )
                        }


                        TodayInsightCard(
                            health:
                                health
                        )
                    }
                    .padding(
                        .horizontal,
                        18
                    )
                    .padding(
                        .bottom,
                        18
                    )
                }
                .refreshable {

                    await health.refresh()
                }
            }
            .navigationTitle(
                "Today"
            )
            .navigationBarTitleDisplayMode(
                .large
            )
        }
    }
}


// MARK: - Daily Vibe

struct DailyVibeCard: View {

    let score: Int


    private var title: String {

        switch score {

        case 90...:
            return "Powered up"

        case 80..<90:
            return "Feeling great"

        case 70..<80:
            return "Feeling good"

        case 55..<70:
            return "Take it steady"

        default:
            return "Recharge"
        }
    }


    private var subtitle: String {

        switch score {

        case 90...:
            return
                "Your recovery looks strong today."

        case 80..<90:
            return
                "You’re in a good place today."

        case 70..<80:
            return
                "A solid day ahead."

        case 55..<70:
            return
                "Take things a little easier."

        default:
            return
                "Your body could use more recovery."
        }
    }


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text(
                "DAILY VIBE"
            )
            .font(
                .caption2
                    .weight(
                        .semibold
                    )
            )
            .foregroundStyle(
                .secondary
            )
            .tracking(
                1.2
            )


            HStack {

                ZStack {

                    Circle()
                        .fill(
                            VitalsTheme.accentSoft
                        )
                        .frame(
                            width: 44,
                            height: 44
                        )


                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        VitalsTheme.accent
                    )
                }


                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(
                        title
                    )
                    .font(
                        .title3
                            .weight(
                                .semibold
                            )
                    )


                    Text(
                        subtitle
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Spacer()


                Text(
                    "\(score)"
                )
                .font(
                    .system(
                        size: 38,
                        weight: .semibold,
                        design: .rounded
                    )
                )
            }


            ProgressView(
                value:
                    Double(score),

                total:
                    100
            )
            .tint(
                VitalsTheme.accent
            )
        }
        .padding(18)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }
}


// MARK: - Readiness Breakdown

struct ReadinessBreakdownCard: View {

    let breakdown:
        ReadinessBreakdown


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Text(
                    "Why this score?"
                )
                .font(
                    .headline
                )


                Spacer()


                Text(
                    "\(Int(breakdown.total.rounded()))"
                )
                .font(
                    .title2
                        .weight(
                            .semibold
                        )
                )
                .foregroundStyle(
                    VitalsTheme.accent
                )
            }


            BreakdownRow(
                title: "HRV",
                value:
                    breakdown.hrvPoints,
                maximum:
                    45,
                icon:
                    "waveform.path.ecg"
            )


            BreakdownRow(
                title:
                    "Resting HR",

                value:
                    breakdown.restingHRPoints,

                maximum:
                    25,

                icon:
                    "heart.fill"
            )


            BreakdownRow(
                title:
                    "Sleep",

                value:
                    breakdown.sleepPoints,

                maximum:
                    30,

                icon:
                    "moon.fill"
            )
        }
        .padding(16)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


struct BreakdownRow: View {

    let title: String

    let value: Double
    let maximum: Double

    let icon: String


    private var progress:
        Double {

        guard maximum > 0 else {
            return 0
        }

        return min(
            max(
                value / maximum,
                0
            ),
            1
        )
    }


    var body: some View {

        HStack(
            spacing: 10
        ) {

            Image(
                systemName: icon
            )
            .font(
                .system(
                    size: 13,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                VitalsTheme.accent
            )
            .frame(
                width: 20
            )


            Text(
                title
            )
            .font(
                .subheadline
            )


            Spacer()


            ProgressView(
                value: progress
            )
            .tint(
                VitalsTheme.accent
            )
            .frame(
                width: 72
            )


            Text(
                "\(Int(value.rounded()))/\(Int(maximum))"
            )
            .font(
                .caption
                    .weight(
                        .semibold
                    )
            )
            .foregroundStyle(
                .secondary
            )
            .frame(
                width: 42,
                alignment: .trailing
            )
        }
    }
}


// MARK: - Daily Check-In

struct CheckInFeeling:
    Identifiable {

    let id =
        UUID()

    let emoji: String
    let label: String
}


struct DailyCheckInCard: View {

    @AppStorage(
        "dailyCheckInFeeling"
    )
    private var selectedFeeling =
        ""


    @AppStorage(
        "dailyCheckInDate"
    )
    private var selectedDate =
        ""


    private let feelings = [

        CheckInFeeling(
            emoji: "😵",
            label: "Rough"
        ),

        CheckInFeeling(
            emoji: "😐",
            label: "Okay"
        ),

        CheckInFeeling(
            emoji: "🙂",
            label: "Good"
        ),

        CheckInFeeling(
            emoji: "⚡️",
            label: "Great"
        )
    ]


    private var todayKey:
        String {

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "yyyy-MM-dd"

        return formatter.string(
            from: Date()
        )
    }


    private var currentFeeling:
        String {

        selectedDate == todayKey
        ? selectedFeeling
        : ""
    }


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    "How do you feel?"
                )
                .font(
                    .headline
                )


                Text(
                    "Your numbers are only half the story."
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
            }


            HStack(
                spacing: 8
            ) {

                ForEach(
                    feelings
                ) { feeling in

                    Button {

                        selectedFeeling =
                            feeling.label

                        selectedDate =
                            todayKey

                    } label: {

                        VStack(
                            spacing: 5
                        ) {

                            Text(
                                feeling.emoji
                            )
                            .font(
                                .system(
                                    size: 24
                                )
                            )


                            Text(
                                feeling.label
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                currentFeeling
                                == feeling.label
                                ? VitalsTheme.accent
                                : .secondary
                            )
                        }
                        .frame(
                            maxWidth:
                                .infinity,

                            minHeight:
                                66
                        )
                        .background(
                            currentFeeling
                            == feeling.label
                            ? VitalsTheme.accentSoft
                            : Color.clear
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }
            }


            if !currentFeeling.isEmpty {

                HStack(
                    spacing: 5
                ) {

                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(
                        VitalsTheme.accent
                    )


                    Text(
                        "Checked in for today · \(currentFeeling)"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
        .padding(16)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


// MARK: - Sleep Metric Card

struct SleepMetricCard: View {

    let value: String


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            ZStack {

                Circle()
                    .fill(
                        VitalsTheme.accentSoft
                    )
                    .frame(
                        width: 34,
                        height: 34
                    )


                Image(
                    systemName:
                        "moon.fill"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    VitalsTheme.accent
                )
            }


            Text(
                "Sleep"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                value
            )
            .font(
                .title3
                    .weight(
                        .semibold
                    )
            )
            .minimumScaleFactor(
                0.75
            )
            .lineLimit(1)


            Spacer(
                minLength: 0
            )


            HStack(
                spacing: 3
            ) {

                Text(
                    "View details"
                )
                .font(
                    .caption2
                        .weight(
                            .semibold
                        )
                )


                Image(
                    systemName:
                        "chevron.right"
                )
                .font(
                    .system(
                        size: 8,
                        weight: .bold
                    )
                )
            }
            .foregroundStyle(
                VitalsTheme.accent
            )
        }
        .frame(
            maxWidth:
                .infinity,

            minHeight:
                136,

            maxHeight:
                136,

            alignment:
                .leading
        )
        .padding(14)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


// MARK: - Metric Card

struct MetricCard: View {

    let title: String
    let value: String
    let icon: String


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            ZStack {

                Circle()
                    .fill(
                        VitalsTheme.accentSoft
                    )
                    .frame(
                        width: 34,
                        height: 34
                    )


                Image(
                    systemName: icon
                )
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    VitalsTheme.accent
                )
            }


            Text(
                title
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                value
            )
            .font(
                .title3
                    .weight(
                        .semibold
                    )
            )
            .minimumScaleFactor(
                0.75
            )
            .lineLimit(1)


            Spacer(
                minLength: 0
            )
        }
        .frame(
            maxWidth:
                .infinity,

            minHeight:
                136,

            maxHeight:
                136,

            alignment:
                .leading
        )
        .padding(14)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


// MARK: - Sleep Details

struct SleepDetailsView: View {

    let details:
        SleepDetailsSnapshot


    private var totalStageHours:
        Double {

        details.remHours
        + details.coreHours
        + details.deepHours
    }


    var body: some View {

        ZStack {

            VitalsTheme.background
                .ignoresSafeArea()


            ScrollView {

                VStack(
                    spacing: 16
                ) {

                    SleepHeroCard(
                        details: details
                    )


                    if let start =
                        details.startDate,
                       let end =
                        details.endDate {

                        HStack(
                            spacing: 12
                        ) {

                            SleepTimeCard(
                                title:
                                    "Fell asleep",

                                value:
                                    start.formatted(
                                        date:
                                            .omitted,

                                        time:
                                            .shortened
                                    ),

                                icon:
                                    "moon.fill"
                            )


                            SleepTimeCard(
                                title:
                                    "Woke up",

                                value:
                                    end.formatted(
                                        date:
                                            .omitted,

                                        time:
                                            .shortened
                                    ),

                                icon:
                                    "sun.max.fill"
                            )
                        }
                    }


                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {

                        Text(
                            "Sleep stages"
                        )
                        .font(
                            .headline
                        )


                        SleepStageRow(
                            title: "REM",
                            value:
                                details.remHours,
                            total:
                                max(
                                    totalStageHours,
                                    0.1
                                ),
                            icon:
                                "sparkles"
                        )


                        SleepStageRow(
                            title: "Core",
                            value:
                                details.coreHours,
                            total:
                                max(
                                    totalStageHours,
                                    0.1
                                ),
                            icon:
                                "circle.fill"
                        )


                        SleepStageRow(
                            title: "Deep",
                            value:
                                details.deepHours,
                            total:
                                max(
                                    totalStageHours,
                                    0.1
                                ),
                            icon:
                                "moon.zzz.fill"
                        )


                        SleepStageMinutesRow(
                            title:
                                "Awake",

                            minutes:
                                details.awakeMinutes,

                            icon:
                                "eye.fill"
                        )
                    }
                    .padding(18)
                    .background(
                        VitalsTheme.card
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                    )


                    SleepScoreExplanationCard(
                        details: details
                    )
                }
                .padding(18)
            }
        }
        .navigationTitle(
            "Sleep"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
}


// MARK: - Sleep Hero

struct SleepHeroCard: View {

    let details:
        SleepDetailsSnapshot


    var body: some View {

        HStack(
            spacing: 20
        ) {

            ZStack {

                Circle()
                    .stroke(
                        VitalsTheme.accentSoft,
                        lineWidth: 9
                    )


                Circle()
                    .trim(
                        from: 0,
                        to:
                            min(
                                details.sleepScore
                                / 100,
                                1
                            )
                    )
                    .stroke(
                        VitalsTheme.accent,
                        style:
                            StrokeStyle(
                                lineWidth: 9,
                                lineCap: .round
                            )
                    )
                    .rotationEffect(
                        .degrees(-90)
                    )


                VStack(
                    spacing: 0
                ) {

                    Text(
                        "\(Int(details.sleepScore.rounded()))"
                    )
                    .font(
                        .system(
                            size: 28,
                            weight: .semibold,
                            design: .rounded
                        )
                    )


                    Text(
                        "SCORE"
                    )
                    .font(
                        .caption2
                            .weight(
                                .semibold
                            )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .frame(
                width: 108,
                height: 108
            )


            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(
                    "Last night"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    formattedDuration(
                        hours:
                            details.totalHours
                    )
                )
                .font(
                    .system(
                        size: 31,
                        weight: .semibold,
                        design: .rounded
                    )
                )


                Text(
                    sleepQuality
                )
                .font(
                    .subheadline
                        .weight(
                            .medium
                        )
                )
                .foregroundStyle(
                    VitalsTheme.accent
                )
            }


            Spacer()
        }
        .padding(18)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }


    private var sleepQuality:
        String {

        switch details.sleepScore {

        case 90...:
            return "Excellent sleep"

        case 80..<90:
            return "Great sleep"

        case 70..<80:
            return "Good sleep"

        case 55..<70:
            return "Fair sleep"

        default:
            return "Could be better"
        }
    }
}


// MARK: - Sleep Time Card

struct SleepTimeCard: View {

    let title: String
    let value: String
    let icon: String


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Image(
                systemName: icon
            )
            .foregroundStyle(
                VitalsTheme.accent
            )


            Text(
                title
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                value
            )
            .font(
                .title3
                    .weight(
                        .semibold
                    )
            )
        }
        .frame(
            maxWidth:
                .infinity,

            alignment:
                .leading
        )
        .padding(16)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


// MARK: - Sleep Stage Row

struct SleepStageRow: View {

    let title: String
    let value: Double
    let total: Double
    let icon: String


    private var progress:
        Double {

        min(
            max(
                value / total,
                0
            ),
            1
        )
    }


    var body: some View {

        VStack(
            spacing: 7
        ) {

            HStack {

                Image(
                    systemName: icon
                )
                .foregroundStyle(
                    VitalsTheme.accent
                )
                .frame(
                    width: 22
                )


                Text(
                    title
                )
                .font(
                    .subheadline
                )


                Spacer()


                Text(
                    formattedDuration(
                        hours: value
                    )
                )
                .font(
                    .subheadline
                        .weight(
                            .semibold
                        )
                )
            }


            ProgressView(
                value: progress
            )
            .tint(
                VitalsTheme.accent
            )
        }
    }
}


struct SleepStageMinutesRow: View {

    let title: String
    let minutes: Double
    let icon: String


    var body: some View {

        HStack {

            Image(
                systemName: icon
            )
            .foregroundStyle(
                VitalsTheme.accent
            )
            .frame(
                width: 22
            )


            Text(
                title
            )
            .font(
                .subheadline
            )


            Spacer()


            Text(
                "\(Int(minutes.rounded())) min"
            )
            .font(
                .subheadline
                    .weight(
                        .semibold
                    )
            )
        }
    }
}


// MARK: - Sleep Score Explanation

struct SleepScoreExplanationCard: View {

    let details:
        SleepDetailsSnapshot


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Label(
                "About your score",
                systemImage:
                    "info.circle.fill"
            )
            .font(
                .headline
            )
            .foregroundStyle(
                VitalsTheme.accent
            )


            Text(
                "Your Zevli sleep score is based on how long you slept and how interrupted your sleep was. Bedtime consistency is intentionally not included."
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )


            if details.interruptionCount > 0 {

                Text(
                    "\(details.interruptionCount) longer wake-up\(details.interruptionCount == 1 ? "" : "s") detected during the night."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(18)
        .frame(
            maxWidth:
                .infinity,

            alignment:
                .leading
        )
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


// MARK: - Duration Formatter

private func formattedDuration(
    hours: Double
) -> String {

    let totalMinutes =
        Int(
            (
                max(
                    hours,
                    0
                )
                * 60
            )
            .rounded()
        )


    let hourPart =
        totalMinutes / 60


    let minutePart =
        totalMinutes % 60


    return
        "\(hourPart)h \(minutePart)m"
}


// MARK: - Today's Insight

struct TodayInsightCard: View {

    @ObservedObject
    var health:
        HealthDashboardStore


    private var message:
        String {

        if health.simpleVibeScore >= 90 {

            return
                "Recovery looks strong today. You’re in a good spot for something active."

        } else if health.simpleVibeScore >= 70 {

            return
                "Things look pretty solid today. Keep an eye on how you feel."

        } else if health.simpleVibeScore >= 55 {

            return
                "Your signals are mixed today. A steadier pace might feel better."

        } else {

            return
                "Your body looks like it could use an easier day and some extra recovery."
        }
    }


    var body: some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        VitalsTheme.accentSoft
                    )
                    .frame(
                        width: 34,
                        height: 34
                    )


                Image(
                    systemName:
                        "lightbulb.fill"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    VitalsTheme.accent
                )
            }


            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(
                    "Today’s insight"
                )
                .font(
                    .headline
                )


                Text(
                    message
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()
        }
        .padding(16)
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}


// MARK: - Insights

struct InsightsView: View {

    @ObservedObject
    var health:
        HealthDashboardStore


    var body: some View {

        NavigationStack {

            ZStack {

                VitalsTheme.background
                    .ignoresSafeArea()


                ScrollView {

                    VStack(
                        spacing: 18
                    ) {

                        InsightsOverallSummaryCard(
                            health: health
                        )


                        HStack(
                            spacing: 14
                        ) {

                            InsightCard(
                                title: "Sleep",

                                icon:
                                    "moon.fill",

                                value:
                                    String(
                                        format: "%.1f h",
                                        health.sleepHours
                                    ),

                                description:
                                    sleepDescription(
                                        hours:
                                            health.sleepHours
                                    )
                            )


                            InsightCard(
                                title: "HRV",

                                icon:
                                    "waveform.path.ecg",

                                value:
                                    "\(Int(health.hrv)) ms",

                                description:
                                    hrvDescription(
                                        hrv:
                                            health.hrv
                                    )
                            )
                        }


                        HStack(
                            spacing: 14
                        ) {

                            InsightCard(
                                title:
                                    "Resting HR",

                                icon:
                                    "heart.fill",

                                value:
                                    "\(Int(health.restingHeartRate)) bpm",

                                description:
                                    restingHRDescription(
                                        rhr:
                                            health.restingHeartRate
                                    )
                            )


                            InsightCard(
                                title:
                                    "Activity",

                                icon:
                                    "flame.fill",

                                value:
                                    "\(Int(health.activeEnergy)) kcal",

                                description:
                                    activityDescription(
                                        kcal:
                                            health.activeEnergy
                                    )
                            )
                        }
                    }
                    .padding(
                        .horizontal,
                        18
                    )
                    .padding(
                        .vertical,
                        20
                    )
                }
                .refreshable {

                    await health.refresh()
                }
            }
            .navigationTitle(
                "Insights"
            )
        }
    }


    private func sleepDescription(
        hours: Double
    ) -> String {

        if hours >= 7.5 {

            return
                "Great sleep duration"

        } else if hours >= 6 {

            return
                "Decent sleep, but could use more"

        } else if hours > 0 {

            return
                "Short sleep, try to get more rest"

        } else {

            return
                "No recent sleep data"
        }
    }


    private func hrvDescription(
        hrv: Double
    ) -> String {

        if hrv >= 80 {

            return
                "Excellent HRV"

        } else if hrv >= 50 {

            return
                "Average HRV"

        } else if hrv > 0 {

            return
                "Low HRV, may need rest"

        } else {

            return
                "No recent HRV data"
        }
    }


    private func restingHRDescription(
        rhr: Double
    ) -> String {

        if rhr > 0 &&
            rhr < 60 {

            return
                "Excellent resting HR"

        } else if rhr >= 60 &&
                    rhr < 75 {

            return
                "Normal resting HR"

        } else if rhr >= 75 {

            return
                "Elevated resting HR"

        } else {

            return
                "No recent RHR data"
        }
    }


    private func activityDescription(
        kcal: Double
    ) -> String {

        if kcal > 700 {

            return
                "Very active day"

        } else if kcal > 400 {

            return
                "Good activity"

        } else if kcal > 0 {

            return
                "Still early — keep moving"

        } else {

            return
                "No recent activity data"
        }
    }
}


// MARK: - Overall Summary

struct InsightsOverallSummaryCard: View {

    @ObservedObject
    var health:
        HealthDashboardStore


    private var overallSummary:
        String {

        let score =
            health.simpleVibeScore


        if score >= 90 {

            return
                "Your recovery is excellent and your metrics are looking great. Today is a good day to challenge yourself."

        } else if score >= 75 {

            return
                "Your overall health signals are positive. Keep maintaining your healthy habits."

        } else if score >= 60 {

            return
                "Some signals are moderate. Consider balancing activity and recovery."

        } else if score > 0 {

            return
                "Your body may need extra rest. Take it easy and focus on recovery."

        } else {

            return
                "Not enough data to provide an overall summary."
        }
    }


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text(
                "Overall Summary"
            )
            .font(
                .headline
            )


            Text(
                overallSummary
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
    }
}


// MARK: - Insight Card

struct InsightCard: View {

    let title: String
    let icon: String
    let value: String
    let description: String


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack(
                spacing: 10
            ) {

                ZStack {

                    Circle()
                        .fill(
                            VitalsTheme.accentSoft
                        )
                        .frame(
                            width: 32,
                            height: 32
                        )


                    Image(
                        systemName: icon
                    )
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        VitalsTheme.accent
                    )
                }


                Text(
                    title
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )


                Spacer()
            }


            Text(
                value
            )
            .font(
                .title3
                    .weight(
                        .semibold
                    )
            )


            Text(
                description
            )
            .font(
                .footnote
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: 120,
            alignment: .leading
        )
        .background(
            VitalsTheme.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }
}


// MARK: - Preview

#Preview {
    ContentView()
}
