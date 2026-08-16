import WidgetKit
import SwiftUI


// MARK: - Provider

struct Provider: AppIntentTimelineProvider {

    func placeholder(
        in context: Context
    ) -> SimpleEntry {

        makeEntry(
            snapshot: .preview,
            configuration: ConfigurationAppIntent()
        )
    }


    func snapshot(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> SimpleEntry {

        makeEntry(
            snapshot: SharedHealthStore.load(),
            configuration: configuration
        )
    }


    func timeline(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {

        let entry =
            makeEntry(
                snapshot: SharedHealthStore.load(),
                configuration: configuration
            )


        let nextRefresh =
            Calendar.current.date(
                byAdding: .minute,
                value: 15,
                to: Date()
            )
            ?? Date().addingTimeInterval(
                15 * 60
            )


        return Timeline(
            entries: [entry],
            policy: .after(nextRefresh)
        )
    }


    func recommendations()
        -> [AppIntentRecommendation<ConfigurationAppIntent>] {

        HealthMetric.allCases.map { metric in

            let intent =
                ConfigurationAppIntent()

            intent.metric =
                metric

            intent.style =
                defaultStyle(
                    for: metric
                )

            return AppIntentRecommendation(
                intent: intent,
                description: metric.displayName
            )
        }
    }


    private func defaultStyle(
        for metric: HealthMetric
    ) -> ComplicationStyle {

        switch metric {

        case .activityRings,
             .sleep,
             .readiness,
             .dailyVibe,
             .activity,
             .recovery,
             .strain:

            return .ring

        default:

            return .iconNumber
        }
    }


    private func makeEntry(
        snapshot: SharedHealthSnapshot,
        configuration: ConfigurationAppIntent
    ) -> SimpleEntry {

        SimpleEntry(
            date: snapshot.updatedAt,
            configuration: configuration,

            sleepHours: snapshot.sleepHours,
            sleepScore: snapshot.sleepScore,

            readiness: snapshot.readiness,
            activity: snapshot.activity,

            hrv: snapshot.hrv,
            restingHeartRate: snapshot.restingHeartRate,
            heartRate: snapshot.heartRate,

            steps: snapshot.steps,
            activeEnergy: snapshot.activeEnergy,
            exerciseMinutes: snapshot.exerciseMinutes,
            standHours: snapshot.standHours,

            moveGoal: snapshot.moveGoal,
            exerciseGoal: snapshot.exerciseGoal,
            standGoal: snapshot.standGoal,

            recovery: snapshot.recovery,
            strain: snapshot.strain
        )
    }
}


// MARK: - Entry

struct SimpleEntry: TimelineEntry {

    let date: Date
    let configuration: ConfigurationAppIntent

    let sleepHours: Double
    let sleepScore: Double

    let readiness: Double
    let activity: Double

    let hrv: Double
    let restingHeartRate: Double
    let heartRate: Double

    let steps: Double
    let activeEnergy: Double
    let exerciseMinutes: Double
    let standHours: Double

    let moveGoal: Double
    let exerciseGoal: Double
    let standGoal: Double

    let recovery: Double
    let strain: Double
}


// MARK: - Metric Helpers

extension HealthMetric {

    var displayName: String {

        switch self {

        case .activityRings:
            return "Activity Rings"

        case .sleep:
            return "Sleep Score"

        case .sleepDuration:
            return "Sleep Duration"

        case .readiness:
            return "Readiness"

        case .dailyVibe:
            return "Daily Vibe"

        case .activity:
            return "Activity"

        case .hrv:
            return "HRV"

        case .restingHeartRate:
            return "Resting HR"

        case .heartRate:
            return "Heart Rate"

        case .steps:
            return "Steps"

        case .activeEnergy:
            return "Active Energy"

        case .exercise:
            return "Exercise"

        case .recovery:
            return "Recovery"

        case .strain:
            return "Strain"
        }
    }


    var shortName: String {

        switch self {

        case .activityRings:
            return "RINGS"

        case .sleep:
            return "SLEEP"

        case .sleepDuration:
            return "SLEEP HRS"

        case .readiness:
            return "READY"

        case .dailyVibe:
            return "VIBE"

        case .restingHeartRate:
            return "REST HR"

        case .activeEnergy:
            return "ENERGY"

        default:
            return displayName.uppercased()
        }
    }


    var systemImage: String {

        switch self {

        case .activityRings:
            return "circle.grid.2x2.fill"

        case .sleep:
            return "moon.fill"

        case .sleepDuration:
            return "bed.double.fill"

        case .readiness:
            return "sparkles"

        case .dailyVibe:
            return "bolt.heart.fill"

        case .activity:
            return "figure.walk"

        case .hrv:
            return "waveform.path.ecg"

        case .restingHeartRate:
            return "heart.text.square.fill"

        case .heartRate:
            return "heart.fill"

        case .steps:
            return "shoeprints.fill"

        case .activeEnergy:
            return "flame.fill"

        case .exercise:
            return "figure.run"

        case .recovery:
            return "heart.circle.fill"

        case .strain:
            return "bolt.fill"
        }
    }


    var deepLinkURL: URL? {

        URL(
            string:
                "zevli://metric/\(rawValue)"
        )
    }
}


// MARK: - Entry Helpers

extension SimpleEntry {

    func value(
        for metric: HealthMetric
    ) -> Double {

        switch metric {

        case .activityRings:
            return activity

        case .sleep:
            return sleepScore

        case .sleepDuration:
            return sleepHours

        case .readiness:
            return readiness

        case .dailyVibe:
            return readiness

        case .activity:
            return activity

        case .hrv:
            return hrv

        case .restingHeartRate:
            return restingHeartRate

        case .heartRate:
            return heartRate

        case .steps:
            return steps

        case .activeEnergy:
            return activeEnergy

        case .exercise:
            return exerciseMinutes

        case .recovery:
            return recovery

        case .strain:
            return strain
        }
    }


    func progress(
        for metric: HealthMetric
    ) -> Double {

        switch metric {

        case .activityRings:
            return min(activity / 100, 1)

        case .sleep:
            return min(sleepScore / 100, 1)

        case .sleepDuration:
            return min(sleepHours / 8, 1)

        case .readiness,
             .dailyVibe,
             .activity,
             .recovery,
             .strain:

            return min(
                value(for: metric) / 100,
                1
            )

        case .hrv:
            return min(hrv / 100, 1)

        case .restingHeartRate:
            return min(
                restingHeartRate / 120,
                1
            )

        case .heartRate:
            return min(
                heartRate / 150,
                1
            )

        case .steps:
            return min(
                steps / 10_000,
                1
            )

        case .activeEnergy:
            return min(
                activeEnergy / max(moveGoal, 1),
                1
            )

        case .exercise:
            return min(
                exerciseMinutes / max(exerciseGoal, 1),
                1
            )
        }
    }


    func formattedValue(
        for metric: HealthMetric
    ) -> String {

        switch metric {

        case .activityRings:
            return "\(Int(activity))%"

        case .sleep:
            return "\(Int(sleepScore))"

        case .sleepDuration:
            return String(
                format: "%.1fh",
                sleepHours
            )

        case .readiness,
             .dailyVibe,
             .activity,
             .recovery,
             .strain:

            return "\(Int(value(for: metric)))%"

        case .hrv:
            return "\(Int(hrv))"

        case .restingHeartRate:
            return "\(Int(restingHeartRate))"

        case .heartRate:
            return "\(Int(heartRate))"

        case .steps:

            if steps >= 1000 {

                return String(
                    format: "%.1fk",
                    steps / 1000
                )
            }

            return "\(Int(steps))"

        case .activeEnergy:
            return "\(Int(activeEnergy))"

        case .exercise:
            return "\(Int(exerciseMinutes))m"
        }
    }


    func readinessStatus() -> String {

        switch readiness {

        case 85...:
            return "HIGH"

        case 70..<85:
            return "GOOD"

        case 50..<70:
            return "OK"

        default:
            return "LOW"
        }
    }


    func vibeTitle() -> String {

        switch readiness {

        case 90...:
            return "POWERED UP"

        case 80..<90:
            return "FEELING GREAT"

        case 70..<80:
            return "FEELING GOOD"

        case 55..<70:
            return "TAKE IT STEADY"

        default:
            return "RECHARGE"
        }
    }


    func vibeSubtitle() -> String {

        switch readiness {

        case 90...:
            return "READY FOR A BIG DAY"

        case 80..<90:
            return "YOU'RE GOOD TO GO"

        case 70..<80:
            return "A SOLID DAY AHEAD"

        case 55..<70:
            return "DON'T OVERDO IT"

        default:
            return "TAKE IT EASY TODAY"
        }
    }
}


// MARK: - Main View

struct VitalsTrack_WatchEntryView: View {

    @Environment(\.widgetFamily)
    private var family

    let entry: SimpleEntry


    private var metric: HealthMetric {
        entry.configuration.metric
    }


    private var style: ComplicationStyle {
        entry.configuration.style
    }


    var body: some View {

        Group {

            switch family {

            case .accessoryCircular:

                CircularComplicationView(
                    metric: normalizedMetric,
                    style: style,
                    entry: entry
                )


            case .accessoryRectangular:

                if metric == .activityRings {

                    ActivityRingsRectangularView(
                        entry: entry
                    )

                } else if metric == .dailyVibe {

                    DailyVibeRectangularView(
                        entry: entry
                    )

                } else {

                    RectangularMetricView(
                        metric: metric,
                        style: style,
                        entry: entry
                    )
                }


            case .accessoryInline:

                Label(
                    "\(normalizedMetric.displayName) \(entry.formattedValue(for: normalizedMetric))",
                    systemImage:
                        normalizedMetric.systemImage
                )


            case .accessoryCorner:

                Text(
                    entry.formattedValue(
                        for: normalizedMetric
                    )
                )
                .widgetLabel {

                    Label(
                        normalizedMetric.displayName,
                        systemImage:
                            normalizedMetric.systemImage
                    )
                }


            default:

                Text(
                    entry.formattedValue(
                        for: normalizedMetric
                    )
                )
            }
        }
        .widgetURL(
            metric.deepLinkURL
        )
    }


    private var normalizedMetric: HealthMetric {

        if metric == .activityRings {
            return .activity
        }

        return metric
    }
}


// MARK: - Activity Rings

struct ActivityRingsRectangularView: View {

    let entry: SimpleEntry


    var body: some View {

        GeometryReader { geometry in

            HStack(spacing: 8) {

                ActivityMiniRing(
                    title: "MOVE",
                    value: "\(Int(entry.activeEnergy))",
                    progress: min(
                        entry.activeEnergy
                        / max(entry.moveGoal, 1),
                        1
                    ),
                    diameter: min(
                        46,
                        geometry.size.height * 0.82
                    )
                )


                ActivityMiniRing(
                    title: "EXERCISE",
                    value: "\(Int(entry.exerciseMinutes))",
                    progress: min(
                        entry.exerciseMinutes
                        / max(entry.exerciseGoal, 1),
                        1
                    ),
                    diameter: min(
                        46,
                        geometry.size.height * 0.82
                    )
                )


                ActivityMiniRing(
                    title: "STAND",
                    value: "\(Int(entry.standHours))",
                    progress: min(
                        entry.standHours
                        / max(entry.standGoal, 1),
                        1
                    ),
                    diameter: min(
                        46,
                        geometry.size.height * 0.82
                    )
                )
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .center
            )
        }
    }
}


struct ActivityMiniRing: View {

    let title: String
    let value: String
    let progress: Double
    let diameter: CGFloat


    var body: some View {

        VStack(spacing: 4) {

            ZStack {

                Circle()
                    .stroke(
                        .secondary.opacity(0.18),
                        lineWidth: 6
                    )


                Circle()
                    .trim(
                        from: 0,
                        to: min(
                            max(progress, 0),
                            1
                        )
                    )
                    .stroke(
                        .primary,
                        style: StrokeStyle(
                            lineWidth: 6,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(
                        .degrees(-90)
                    )
                    .widgetAccentable()


                Text(value)
                    .font(
                        .system(
                            size: 13,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            .frame(
                width: diameter,
                height: diameter
            )


            Text(title)
                .font(
                    .system(
                        size: 6,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}


// MARK: - Daily Vibe

struct DailyVibeRectangularView: View {

    let entry: SimpleEntry


    private var score: Double {

        min(
            max(entry.readiness, 0),
            100
        )
    }


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            HStack(
                alignment: .firstTextBaseline
            ) {

                Image(
                    systemName: "bolt.heart.fill"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .widgetAccentable()


                Text(
                    entry.vibeTitle()
                )
                .font(
                    .system(
                        size: 10,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)


                Spacer(
                    minLength: 4
                )


                Text(
                    "\(Int(score))%"
                )
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
            }


            GeometryReader { geometry in

                ZStack(
                    alignment: .leading
                ) {

                    Capsule()
                        .fill(
                            .secondary.opacity(
                                0.18
                            )
                        )


                    Capsule()
                        .fill(.primary)
                        .frame(
                            width:
                                geometry.size.width
                                * score
                                / 100
                        )
                        .widgetAccentable()
                }
            }
            .frame(
                height: 6
            )


            Text(
                entry.vibeSubtitle()
            )
            .font(
                .system(
                    size: 6.5,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .leading
        )
    }
}


// MARK: - Circular

struct CircularComplicationView: View {

    let metric: HealthMetric
    let style: ComplicationStyle
    let entry: SimpleEntry


    var body: some View {

        switch style {

        case .ring:

            CircularRingMetricView(
                metric: metric,
                entry: entry
            )

        case .iconNumber:

            CircularIconNumberView(
                metric: metric,
                entry: entry
            )

        case .number:

            CircularNumberView(
                metric: metric,
                entry: entry
            )

        case .progress:

            CircularProgressView(
                metric: metric,
                entry: entry
            )
        }
    }
}


// MARK: - Circular Ring

struct CircularRingMetricView: View {

    let metric: HealthMetric
    let entry: SimpleEntry


    var body: some View {

        ZStack {

            if metric != .readiness {

                Circle()
                    .stroke(
                        .secondary.opacity(0.20),
                        lineWidth: 4
                    )


                Circle()
                    .trim(
                        from: 0,
                        to: entry.progress(
                            for: metric
                        )
                    )
                    .stroke(
                        .primary,
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(
                        .degrees(-90)
                    )
                    .widgetAccentable()
            }


            VStack(
                spacing:
                    metric == .readiness
                    ? 1
                    : 0
            ) {

                Image(
                    systemName:
                        metric.systemImage
                )
                .font(
                    .system(
                        size:
                            metric == .readiness
                            ? 13
                            : 9,
                        weight: .semibold
                    )
                )
                .widgetAccentable()


                Text(
                    entry.formattedValue(
                        for: metric
                    )
                )
                .font(
                    .system(
                        size:
                            metric == .readiness
                            ? 15
                            : 9,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .minimumScaleFactor(0.55)
                .lineLimit(1)


                if metric == .readiness {

                    Text(
                        entry.readinessStatus()
                    )
                    .font(
                        .system(
                            size: 6,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}


// MARK: - Circular Icon + Number

struct CircularIconNumberView: View {

    let metric: HealthMetric
    let entry: SimpleEntry


    var body: some View {

        VStack(spacing: 1) {

            Image(
                systemName:
                    metric.systemImage
            )
            .font(
                .system(
                    size: 13,
                    weight: .semibold
                )
            )
            .widgetAccentable()


            Text(
                entry.formattedValue(
                    for: metric
                )
            )
            .font(
                .system(
                    size: 12,
                    weight: .bold,
                    design: .rounded
                )
            )
            .minimumScaleFactor(0.55)
            .lineLimit(1)


            Text(
                metric == .readiness
                ? entry.readinessStatus()
                : metric.shortName
            )
            .font(
                .system(
                    size: 5.5,
                    weight: .medium,
                    design: .rounded
                )
            )
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}


// MARK: - Circular Number

struct CircularNumberView: View {

    let metric: HealthMetric
    let entry: SimpleEntry


    var body: some View {

        VStack(spacing: 0) {

            Text(
                entry.formattedValue(
                    for: metric
                )
            )
            .font(
                .system(
                    size: 16,
                    weight: .bold,
                    design: .rounded
                )
            )
            .widgetAccentable()
            .minimumScaleFactor(0.55)
            .lineLimit(1)


            Text(
                metric == .readiness
                ? entry.readinessStatus()
                : metric.shortName
            )
            .font(
                .system(
                    size: 6,
                    weight: .medium,
                    design: .rounded
                )
            )
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}


// MARK: - Circular Progress

struct CircularProgressView: View {

    let metric: HealthMetric
    let entry: SimpleEntry


    var body: some View {

        Gauge(
            value:
                entry.progress(
                    for: metric
                ),
            in: 0...1
        ) {

            Image(
                systemName:
                    metric.systemImage
            )

        } currentValueLabel: {

            Text(
                entry.formattedValue(
                    for: metric
                )
            )
            .font(
                .system(
                    size: 9,
                    weight: .bold,
                    design: .rounded
                )
            )
            .minimumScaleFactor(0.55)
        }
        .gaugeStyle(
            .accessoryCircular
        )
        .widgetAccentable()
    }
}


// MARK: - Rectangular

struct RectangularMetricView: View {

    let metric: HealthMetric
    let style: ComplicationStyle
    let entry: SimpleEntry


    var body: some View {

        HStack(spacing: 8) {

            Image(
                systemName:
                    metric.systemImage
            )
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .widgetAccentable()


            VStack(
                alignment: .leading,
                spacing: 1
            ) {

                Text(
                    entry.formattedValue(
                        for: metric
                    )
                )
                .font(
                    .system(
                        size: 20,
                        weight: .bold,
                        design: .rounded
                    )
                )


                Text(
                    metric.displayName
                        .uppercased()
                )
                .font(
                    .system(
                        size: 7,
                        weight: .medium
                    )
                )
                .foregroundStyle(.secondary)
            }


            Spacer()
        }
    }
}


// MARK: - Widget

struct VitalsTrack_Watch: Widget {

    let kind =
        "VitalsTrack_Watch"


    var body: some WidgetConfiguration {

        AppIntentConfiguration(
            kind: kind,
            intent:
                ConfigurationAppIntent.self,
            provider:
                Provider()
        ) { entry in

            VitalsTrack_WatchEntryView(
                entry: entry
            )
            .containerBackground(
                .clear,
                for: .widget
            )
        }
        .configurationDisplayName(
            "Zevli"
        )
        .description(
            "Choose your health metric and complication style."
        )
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}


// MARK: - Preview Helpers

private extension ConfigurationAppIntent {

    static func preview(
        metric: HealthMetric,
        style: ComplicationStyle
    ) -> ConfigurationAppIntent {

        let intent =
            ConfigurationAppIntent()

        intent.metric =
            metric

        intent.style =
            style

        return intent
    }
}


private extension SimpleEntry {

    static func preview(
        metric: HealthMetric,
        style: ComplicationStyle
    ) -> SimpleEntry {

        SimpleEntry(
            date: .now,

            configuration:
                .preview(
                    metric: metric,
                    style: style
                ),

            sleepHours: 7.8,
            sleepScore: 90,

            readiness: 97,
            activity: 64,

            hrv: 102,
            restingHeartRate: 55,
            heartRate: 59,

            steps: 956,
            activeEnergy: 159,
            exerciseMinutes: 1,
            standHours: 5,

            moveGoal: 300,
            exerciseGoal: 30,
            standGoal: 10,

            recovery: 97,
            strain: 35
        )
    }
}


// MARK: - Previews

#Preview(
    "Activity Rings",
    as: .accessoryRectangular
) {

    VitalsTrack_Watch()

} timeline: {

    SimpleEntry.preview(
        metric: .activityRings,
        style: .ring
    )
}


#Preview(
    "Daily Vibe",
    as: .accessoryRectangular
) {

    VitalsTrack_Watch()

} timeline: {

    SimpleEntry.preview(
        metric: .dailyVibe,
        style: .ring
    )
}


#Preview(
    "Sleep Score",
    as: .accessoryCircular
) {

    VitalsTrack_Watch()

} timeline: {

    SimpleEntry.preview(
        metric: .sleep,
        style: .ring
    )
}


#Preview(
    "Sleep Duration",
    as: .accessoryCircular
) {

    VitalsTrack_Watch()

} timeline: {

    SimpleEntry.preview(
        metric: .sleepDuration,
        style: .iconNumber
    )
}


#Preview(
    "Readiness",
    as: .accessoryCircular
) {

    VitalsTrack_Watch()

} timeline: {

    SimpleEntry.preview(
        metric: .readiness,
        style: .ring
    )
}


#Preview(
    "Steps",
    as: .accessoryCircular
) {

    VitalsTrack_Watch()

} timeline: {

    SimpleEntry.preview(
        metric: .steps,
        style: .iconNumber
    )
}
