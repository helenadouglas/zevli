import Foundation

struct ReadinessResult {
    let score: Int

    let hrvScore: Double
    let restingHeartRateScore: Double
    let sleepScore: Double

    let hrvChangePercent: Double
    let restingHeartRateChangePercent: Double
    let sleepChangePercent: Double

    let summary: String
}


struct ReadinessEngine {

    static func calculate(
        currentHRV: Double,
        baselineHRV: Double,

        currentRestingHeartRate: Double,
        baselineRestingHeartRate: Double,

        currentSleepHours: Double,
        baselineSleepHours: Double
    ) -> ReadinessResult {

        let safeBaselineHRV =
            max(
                baselineHRV,
                1
            )

        let safeBaselineRestingHeartRate =
            max(
                baselineRestingHeartRate,
                1
            )

        let safeBaselineSleep =
            max(
                baselineSleepHours,
                1
            )


        // MARK: - HRV

        let hrvRatio =
            currentHRV
            / safeBaselineHRV

        let hrvScore =
            normalizedScore(
                ratio: hrvRatio,
                idealRatio: 1.05,
                badRatio: 0.75
            )

        let hrvChangePercent =
            (
                currentHRV
                - safeBaselineHRV
            )
            / safeBaselineHRV
            * 100


        // MARK: - Resting Heart Rate
        //
        // Lower than baseline is generally better,
        // so we flip the ratio here.

        let restingHeartRateRatio =
            safeBaselineRestingHeartRate
            / max(
                currentRestingHeartRate,
                1
            )

        let restingHeartRateScore =
            normalizedScore(
                ratio: restingHeartRateRatio,
                idealRatio: 1.05,
                badRatio: 0.80
            )

        let restingHeartRateChangePercent =
            (
                currentRestingHeartRate
                - safeBaselineRestingHeartRate
            )
            / safeBaselineRestingHeartRate
            * 100


        // MARK: - Sleep

        let sleepRatio =
            currentSleepHours
            / safeBaselineSleep

        let sleepScore =
            normalizedScore(
                ratio: sleepRatio,
                idealRatio: 1.05,
                badRatio: 0.70
            )

        let sleepChangePercent =
            (
                currentSleepHours
                - safeBaselineSleep
            )
            / safeBaselineSleep
            * 100


        // MARK: - Weighted Readiness

        let weightedScore =
            (
                hrvScore * 0.40
                + restingHeartRateScore * 0.30
                + sleepScore * 0.30
            )


        let finalScore =
            Int(
                weightedScore
                    .rounded()
            )


        return ReadinessResult(
            score:
                min(
                    max(
                        finalScore,
                        0
                    ),
                    100
                ),

            hrvScore:
                hrvScore,

            restingHeartRateScore:
                restingHeartRateScore,

            sleepScore:
                sleepScore,

            hrvChangePercent:
                hrvChangePercent,

            restingHeartRateChangePercent:
                restingHeartRateChangePercent,

            sleepChangePercent:
                sleepChangePercent,

            summary:
                summary(
                    score: finalScore,
                    hrvChange: hrvChangePercent,
                    restingHeartRateChange:
                        restingHeartRateChangePercent,
                    sleepChange:
                        sleepChangePercent
                )
        )
    }


    // MARK: - Normalize

    private static func normalizedScore(
        ratio: Double,
        idealRatio: Double,
        badRatio: Double
    ) -> Double {

        if ratio >= idealRatio {
            return 100
        }

        if ratio <= badRatio {
            return 20
        }

        let progress =
            (
                ratio
                - badRatio
            )
            /
            (
                idealRatio
                - badRatio
            )

        return
            20
            + progress * 80
    }


    // MARK: - Summary

    private static func summary(
        score: Int,
        hrvChange: Double,
        restingHeartRateChange: Double,
        sleepChange: Double
    ) -> String {

        if score >= 85 {

            if hrvChange > 5 {
                return
                    "Your HRV is above your recent baseline and your body looks well recovered."
            }

            return
                "Your recent health signals suggest strong readiness today."
        }


        if score >= 70 {

            return
                "Your health signals are close to your recent baseline."
        }


        if score >= 50 {

            if sleepChange < -10 {
                return
                    "Your sleep was below your recent baseline, which is lowering readiness."
            }

            if restingHeartRateChange > 8 {
                return
                    "Your resting heart rate is elevated compared with your recent baseline."
            }

            return
                "Some of your health signals are below their recent baseline today."
        }


        if hrvChange < -15 {

            return
                "Your HRV is substantially below your recent baseline today."
        }


        return
            "Several health signals are below your recent baseline. Consider a lighter day."
    }
}
