import Foundation


struct SharedHealthSnapshot: Codable {

    var updatedAt: Date

    var sleepHours: Double
    var sleepScore: Double

    var readiness: Double
    var activity: Double

    var hrv: Double
    var restingHeartRate: Double
    var heartRate: Double

    var steps: Double
    var activeEnergy: Double
    var exerciseMinutes: Double
    var standHours: Double

    var moveGoal: Double
    var exerciseGoal: Double
    var standGoal: Double

    var recovery: Double
    var strain: Double


    static let empty =
        SharedHealthSnapshot(
            updatedAt:
                .distantPast,

            sleepHours:
                0,

            sleepScore:
                0,

            readiness:
                0,

            activity:
                0,

            hrv:
                0,

            restingHeartRate:
                0,

            heartRate:
                0,

            steps:
                0,

            activeEnergy:
                0,

            exerciseMinutes:
                0,

            standHours:
                0,

            moveGoal:
                300,

            exerciseGoal:
                30,

            standGoal:
                10,

            recovery:
                0,

            strain:
                0
        )


    static let preview =
        SharedHealthSnapshot(
            updatedAt:
                .now,

            sleepHours:
                8.0,

            sleepScore:
                100,

            readiness:
                82,

            activity:
                64,

            hrv:
                62,

            restingHeartRate:
                65,

            heartRate:
                72,

            steps:
                11_648,

            activeEnergy:
                320,

            exerciseMinutes:
                24,

            standHours:
                8,

            moveGoal:
                300,

            exerciseGoal:
                30,

            standGoal:
                10,

            recovery:
                82,

            strain:
                35
        )
}


// MARK: - Shared Store

enum SharedHealthStore {

    static let appGroup =
        "group.com.helenadouglas.vitalstrack"


    static let snapshotKey =
        "healthSnapshot"


    static let widgetKind =
        "VitalsTrack_Watch"


    static var defaults:
        UserDefaults? {

        UserDefaults(
            suiteName:
                appGroup
        )
    }


    static func save(
        _ snapshot:
            SharedHealthSnapshot
    ) {

        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        snapshot
                    )
        else {
            return
        }


        defaults?.set(
            data,
            forKey:
                snapshotKey
        )
    }


    static func load()
        -> SharedHealthSnapshot {

        guard
            let data =
                defaults?
                    .data(
                        forKey:
                            snapshotKey
                    ),

            let snapshot =
                try? JSONDecoder()
                    .decode(
                        SharedHealthSnapshot.self,
                        from:
                            data
                    )

        else {

            return .empty
        }


        return snapshot
    }
}
