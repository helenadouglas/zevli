//
//  ContentView.swift
//  VitalsTrack Watch Watch App
//
//  Created by Helena Douglas on 15/08/2026.
//

import SwiftUI

struct ContentView: View {

    @State private var isRefreshing = false
    @State private var selectedMetric: String?

    private let health = WatchHealthDataProvider()

    var body: some View {
        Group {
            if let selectedMetric {
                MetricDetailView(
                    metric: selectedMetric,
                    snapshot: SharedHealthStore.load()
                )
            } else {
                ZevliHomeView(
                    isRefreshing: isRefreshing,
                    onRefresh: {
                        Task {
                            await refresh()
                        }
                    }
                )
            }
        }
        .task {
            await refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .zevliMetricDeepLink
            )
        ) { notification in
            guard let metric = notification.object as? String else {
                return
            }

            selectedMetric = metric
        }
    }

    @MainActor
    private func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        await health.refreshSharedSnapshot()
        isRefreshing = false
    }
}


// MARK: - Home

struct ZevliHomeView: View {

    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 32))

                Text("Zevli")
                    .font(.headline)

                Text("Your health at a glance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onRefresh) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Label(
                            "Refresh",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .disabled(isRefreshing)
            }
            .padding()
        }
    }
}


// MARK: - Metric Detail

struct MetricDetailView: View {

    let metric: String
    let snapshot: SharedHealthSnapshot

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(mainValue)
                    .font(
                        .system(
                            size: 30,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                if !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var title: String {
        switch metric {
        case "sleep":
            return "SLEEP"

        case "sleepDuration":
            return "SLEEP DURATION"

        case "steps":
            return "STEPS"

        case "readiness":
            return "READINESS"

        case "dailyVibe":
            return "DAILY VIBE"

        case "heartRate":
            return "HEART RATE"

        case "restingHeartRate":
            return "RESTING HR"

        case "hrv":
            return "HRV"

        case "activeEnergy":
            return "ACTIVE ENERGY"

        case "exercise":
            return "EXERCISE"

        case "activityRings":
            return "ACTIVITY"

        case "activity":
            return "ACTIVITY"

        case "recovery":
            return "RECOVERY"

        case "strain":
            return "STRAIN"

        default:
            return metric.uppercased()
        }
    }

    private var icon: String {
        switch metric {
        case "sleep":
            return "moon.fill"

        case "sleepDuration":
            return "bed.double.fill"

        case "steps":
            return "shoeprints.fill"

        case "readiness":
            return "sparkles"

        case "dailyVibe":
            return "bolt.heart.fill"

        case "heartRate":
            return "heart.fill"

        case "restingHeartRate":
            return "heart.text.square.fill"

        case "hrv":
            return "waveform.path.ecg"

        case "activeEnergy":
            return "flame.fill"

        case "exercise":
            return "figure.run"

        case "activityRings", "activity":
            return "circle.grid.2x2.fill"

        case "recovery":
            return "heart.circle.fill"

        case "strain":
            return "bolt.fill"

        default:
            return "heart.fill"
        }
    }

    private var mainValue: String {
        switch metric {
        case "sleep":
            return "\(Int(snapshot.sleepScore.rounded()))"

        case "sleepDuration":
            return String(
                format: "%.1f h",
                snapshot.sleepHours
            )

        case "steps":
            return "\(Int(snapshot.steps))"

        case "readiness", "dailyVibe":
            return "\(Int(snapshot.readiness.rounded()))%"

        case "heartRate":
            return "\(Int(snapshot.heartRate.rounded())) bpm"

        case "restingHeartRate":
            return "\(Int(snapshot.restingHeartRate.rounded())) bpm"

        case "hrv":
            return "\(Int(snapshot.hrv.rounded())) ms"

        case "activeEnergy":
            return "\(Int(snapshot.activeEnergy.rounded())) kcal"

        case "exercise":
            return "\(Int(snapshot.exerciseMinutes.rounded())) min"

        case "activityRings", "activity":
            return "\(Int(snapshot.activity.rounded()))%"

        case "recovery":
            return "\(Int(snapshot.recovery.rounded()))%"

        case "strain":
            return "\(Int(snapshot.strain.rounded()))%"

        default:
            return "—"
        }
    }

    private var secondaryText: String {
        switch metric {
        case "sleep":
            return "\(String(format: "%.1f h", snapshot.sleepHours)) last night"

        case "sleepDuration":
            return "Last night's sleep"

        case "steps":
            let percentage = Int(
                min(
                    snapshot.steps / 10_000 * 100,
                    100
                )
            )

            return "\(percentage)% of 10,000"

        case "readiness":
            return readinessStatus

        case "dailyVibe":
            return vibeText

        case "heartRate":
            return "Latest recorded heart rate"

        case "restingHeartRate":
            return "Resting heart rate"

        case "hrv":
            return "Heart rate variability"

        case "activeEnergy":
            return "Active energy today"

        case "exercise":
            return "Exercise today"

        case "activityRings":
            return """
            Move \(Int(snapshot.activeEnergy)) kcal · Exercise \(Int(snapshot.exerciseMinutes)) min · Stand \(Int(snapshot.standHours)) h
            """

        case "activity":
            return "Today's activity"

        case "recovery":
            return "Your recovery today"

        case "strain":
            return "Today's activity strain"

        default:
            return ""
        }
    }

    private var readinessStatus: String {
        switch snapshot.readiness {
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

    private var vibeText: String {
        switch snapshot.readiness {
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
}


// MARK: - Deep Link Notification

extension Notification.Name {
    static let zevliMetricDeepLink =
        Notification.Name("zevliMetricDeepLink")
}


// MARK: - Preview

#Preview {
    ContentView()
}
