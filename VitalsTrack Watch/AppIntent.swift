import WidgetKit
import AppIntents


// MARK: - Health Metric

enum HealthMetric: String, AppEnum, CaseIterable {

    case activityRings

    case sleep
    case sleepDuration

    case readiness
    case dailyVibe
    case activity

    case hrv
    case restingHeartRate
    case heartRate

    case steps
    case activeEnergy
    case exercise

    case recovery
    case strain


    static var typeDisplayRepresentation =
        TypeDisplayRepresentation(
            name: "Metric"
        )


    static var caseDisplayRepresentations:
        [HealthMetric: DisplayRepresentation] = [

            .activityRings: "Activity Rings",

            .sleep: "Sleep Score",
            .sleepDuration: "Sleep Duration",

            .readiness: "Readiness",
            .dailyVibe: "Daily Vibe",
            .activity: "Activity",

            .hrv: "HRV",
            .restingHeartRate: "Resting Heart Rate",
            .heartRate: "Heart Rate",

            .steps: "Steps",
            .activeEnergy: "Active Energy",
            .exercise: "Exercise",

            .recovery: "Recovery",
            .strain: "Strain"
        ]
}


// MARK: - Complication Style

enum ComplicationStyle: String, AppEnum, CaseIterable {

    case ring
    case iconNumber
    case number
    case progress


    static var typeDisplayRepresentation =
        TypeDisplayRepresentation(
            name: "Style"
        )


    static var caseDisplayRepresentations:
        [ComplicationStyle: DisplayRepresentation] = [

            .ring: "Ring",
            .iconNumber: "Icon + Number",
            .number: "Number",
            .progress: "Progress"
        ]
}


// MARK: - Configuration

struct ConfigurationAppIntent:
    WidgetConfigurationIntent {

    static var title:
        LocalizedStringResource =
            "Zevli Complication"


    static var description =
        IntentDescription(
            "Choose the health metric and style for this complication."
        )


    @Parameter(
        title: "Metric",
        default: .steps
    )
    var metric: HealthMetric


    @Parameter(
        title: "Style",
        default: .iconNumber
    )
    var style: ComplicationStyle
}
